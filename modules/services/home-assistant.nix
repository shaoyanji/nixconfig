# Home Assistant device-layer stack: Home Assistant + Mosquitto MQTT broker
# + Uptime-Kuma service monitoring + hardware telemetry.
#
# Reusable NixOS module for hosting Home Assistant with a local loopback
# MQTT broker (Mosquitto), Uptime-Kuma status dashboards, and system
# telemetry sensors.
#
# WHAT THIS MODULE CANNOT DECLARE — and why there is no `mqtt:` stanza below.
# Home Assistant's MQTT integration is **config-entry only**: the client is
# created from an entry in `<configDir>/.storage/core.config_entries`, not from
# YAML. Verified in the pinned `homeassistant-2026.9.4`:
#
#   * `components/mqtt/__init__.py` has a `CONFIG_SCHEMA` but its
#     `async_setup()` only registers the publish/websocket actions — it does not
#     build a client. A YAML `mqtt:` block with no active entry instead raises
#     the repair issue `yaml_setup_without_active_setup` (a WARNING).
#   * The broker connection is read in `async_setup_entry()` from
#     `entry.data[CONF_BROKER]`, i.e. from the config entry.
#   * `components/mqtt/config_flow.py` has no `async_step_import`, so YAML is not
#     imported into an entry either — the only YAML path left is
#     `async_step_export_yaml`, which *exports* the entry as a template.
#
# So emitting `mqtt = { broker = ...; }` here would be actively wrong: it would
# add a permanent warning and still subscribe nothing. The supported path is a
# one-time UI/config-flow entry, which HA owns and rewrites — hand-seeding
# `.storage/core.config_entries` from Nix would clobber every other entry
# (github, met, ipp, mobile_app) on every write, the same class of mistake as  # seeding Uptime-Kuma's SQLite DB (see AGENTS.nix `exp-008`).
#
# The gap is therefore made *visible and testable* instead of declared:
# `task checks:ha:mqtt` fails while the broker has no Home Assistant client, so
# "MQTT stack declared but not wired" can never silently pass again (HC-5).
{
  config,
  lib,
  ...
}: let
  cfg = config.services.ha-stack;
in {
  options.services.ha-stack = {
    enable = lib.mkEnableOption "Home Assistant IoT & device stack";

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/private/home-assistant";
      description = "Home Assistant configuration and state directory";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8123;
      description = ''
        Port Home Assistant listens on (written to `http.server_port`). The
        nginx vhost and the firewall rule both read this value, so the port is
        declared here and nowhere else.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open {option}`port` in the firewall directly";
    };

    mqtt = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable loopback Mosquitto MQTT broker on 127.0.0.1:1883";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 1883;
        description = "Mosquitto listen port";
      };
      address = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Mosquitto listen address";
      };
    };

    uptime-kuma = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Uptime-Kuma service status dashboard";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 3001;
        description = "Uptime-Kuma listening port";
      };
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open Uptime-Kuma port in firewall";
      };
    };

    telemetry = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable host battery and AC power telemetry sensors (laptop-as-UPS)";
      };
      prefix = lib.mkOption {
        type = lib.types.str;
        default = config.networking.hostName;
        description = "Device name prefix for telemetry sensors";
      };
    };

    extraComponents = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "rest"
        "command_line"
        "todoist"
        "jellyfin"
        "plex"
        "fritzbox"
        "github"
        "immich"
        "met"
        "ipp"
        "mqtt"
      ];
      description = ''
        Extra Home Assistant **Python dependencies** — not "enabled components".
        Nixpkgs installs these into the Home Assistant environment; it does not
        configure the matching integration. An integration from this list is only
        live once it has a config entry (or YAML support). Measured against
        `configDir/.storage/core.config_entries` and the rendered
        `configuration.yaml`, 4 of the 11 defaults are actually active
        (`command_line` via the rendered block, `github`, `met`, `ipp`) and 7 are
        dependency-only (`rest`, `todoist`, `jellyfin`, `plex`, `fritzbox`,
        `immich`, `mqtt`). Adding a name here makes an integration *available*;
        it does not turn it on.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = ps: [ps.androidtvremote2];
      description = "Extra Python packages for Home Assistant";
    };
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant = {
      enable = true;
      inherit (cfg) configDir extraComponents extraPackages;
      config = {
        default_config = {};
        # Reverse-proxied via nginx (ha.frieren.lan vhost from the service
        # exposure registry). Without a trusted proxy HA rejects every proxied
        # request with "400: Bad Request" (host header not in trusted_domains).
        http = {
          server_port = cfg.port;
          use_x_forwarded_for = true;
          trusted_proxies = ["127.0.0.1" "::1"];
        };
        command_line = lib.mkIf cfg.telemetry.enable [
          {
            sensor = {
              name = "${cfg.telemetry.prefix} Battery Level";
              command = "cat /sys/class/power_supply/BAT0/capacity";
              unit_of_measurement = "%";
              device_class = "battery";
            };
          }
          {
            sensor = {
              name = "${cfg.telemetry.prefix} Battery Status";
              command = "cat /sys/class/power_supply/BAT0/status";
              icon = "mdi:battery-charging";
            };
          }
          {
            binary_sensor = {
              name = "${cfg.telemetry.prefix} AC Connected";
              command = "cat /sys/class/power_supply/ADP0/online";
              payload_on = "1";
              payload_off = "0";
              device_class = "power";
            };
          }
        ];
      };
    };

    # Mosquitto MQTT broker (loopback-only, anonymous)
    services.mosquitto = lib.mkIf cfg.mqtt.enable {
      enable = true;
      listeners = [
        {
          port = cfg.mqtt.port;
          address = cfg.mqtt.address;
          settings.allow_anonymous = true;
        }
      ];
    };

    # Uptime-Kuma status dashboards
    services.uptime-kuma = lib.mkIf cfg.uptime-kuma.enable {
      enable = true;
      settings = {
        PORT = builtins.toString cfg.uptime-kuma.port;
      };
    };
    networking.firewall.allowedTCPPorts = lib.mkMerge [
      (lib.mkIf cfg.openFirewall [cfg.port])
      (lib.mkIf (cfg.uptime-kuma.enable && cfg.uptime-kuma.openFirewall) [
        cfg.uptime-kuma.port
      ])
    ];
  };
}
