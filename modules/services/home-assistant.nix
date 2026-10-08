# Home Assistant device-layer stack: Home Assistant + Mosquitto MQTT broker
# + Uptime-Kuma service monitoring + hardware telemetry.
#
# Reusable NixOS module for hosting Home Assistant with a local loopback
# MQTT broker (Mosquitto), Uptime-Kuma status dashboards, and system
# telemetry sensors.
{
  config,
  pkgs,
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

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open Home Assistant (port 8123) in firewall directly";
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
      description = "Extra Home Assistant components";
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
      openFirewall = cfg.openFirewall;
      config = {
        default_config = {};
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
    networking.firewall.allowedTCPPorts = lib.mkIf (cfg.uptime-kuma.enable && cfg.uptime-kuma.openFirewall) [
      cfg.uptime-kuma.port
    ];
  };
}
