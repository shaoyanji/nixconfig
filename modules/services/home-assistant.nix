# Home Assistant device-layer stack: HA + Mosquitto; Hue/Ambilight lead, zigbee stays opt-in
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.ha-stack;
  dev = cfg.devices;
  extraPy = ps:
    map (
      n:
        if builtins.hasAttr n ps
        then builtins.getAttr n ps
        else throw "services.ha-stack.extraPythonPackages: '${n}' is not in pkgs.python3Packages"
    )
    cfg.extraPythonPackages;
  haComponents = lib.unique (
    cfg.extraComponents
    ++ lib.optional dev.zha.enable "zha"
    ++ lib.optional dev.esphome.enable "esphome"
    ++ lib.optional dev.zigbee2mqtt.enable "mqtt"
  );
  declaredPorts =
    [cfg.port cfg.mqtt.port]
    ++ lib.optional cfg.uptime-kuma.enable cfg.uptime-kuma.port
    ++ lib.optional dev.zigbee2mqtt.enable dev.zigbee2mqtt.port
    ++ lib.optional dev.esphome.enable dev.esphome.port;
  dupPorts = lib.subtractLists (lib.unique declaredPorts) declaredPorts;
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
        "hue"
        "philips_js"
        "cast"
      ];
      description = ''
        Extra Home Assistant **Python dependencies** — not "enabled components".
        Nixpkgs installs these into the Home Assistant environment; it does not
        configure the matching integration. An integration from this list is only
        live once it has a config entry (or YAML support). Measured against
        `configDir/.storage/core.config_entries` and the rendered
        `configuration.yaml`, 4 of the 14 defaults are actually active
        (`command_line` via the rendered block, `github`, `met`, `ipp`) and the
        rest are dependency-only (`rest`, `todoist`, `jellyfin`, `plex`,
        `fritzbox`, `immich`, `mqtt`; `hue`, `philips_js` and `cast` wait for
        SSDP discovery to offer a config flow). Adding a name here makes an
        integration *available*; it does not turn it on.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = ps: [ps.androidtvremote2];
      description = "Extra Python packages for Home Assistant";
    };

    extraPythonPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["aiohue" "ha-philipsjs"];
      example = ["androidtvremote2" "hue-ble"];
      description = ''
        The one-line way to add a Home Assistant Python dependency: attribute
        names resolved against `pkgs.python3Packages`, appended onto whatever
        `extraPackages` returns. A name that is not a real attribute fails the
        eval with the option name in the error, so a typo cannot reach a
        rebuild. Prefer this over writing `extraPackages` yourself; keep
        `extraPackages` only for a package outside python3Packages.
      '';
    };

    devices = {
      hue = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Declare a Philips Hue bridge on this LAN (deps already ship via extraComponents)";
        };
        bridgeIP = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "192.168.3.40";
          description = ''
            The bridge's LAN address. Hue is a config-flow integration: the
            `hue` component and aiohue are already installed, SSDP discovery
            (part of `default_config`) finds the bridge on the LAN, and the
            pairing (link button → application key) completes in the HA UI.
            This value is a declarative record of where it lives — HA's own
            discovery is what actually wires it.
          '';
        };
      };

      ambilightTV = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Declare a Philips Ambilight TV on this LAN (philips_js, JointSPACE :1925/:1926)";
        };
        host = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "192.168.3.26";
          description = ''
            The TV's LAN address. Philips TVs answer the JointSPACE API on
            1925/1926 (probe `GET http://<host>:1925/1/system` for the model).
            Like hue this is a config-flow integration — discovery offers it
            in the HA UI and digest-auth pairing completes there. Measured on
            frieren's LAN 2026-11-19: a 65OLED759/12 answers 192.168.3.26:1925
            with api_version 6.1.
          '';
        };
      };

      zigbee2mqtt = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Run upstream services.zigbee2mqtt; requires mqtt.enable";
        };
        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "/srv/private/zigbee2mqtt";
          description = "Zigbee2MQTT state dir; backed up with /srv/private";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 8080;
          description = "Zigbee2MQTT frontend port (loopback; proxy for LAN)";
        };
        serialPort = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "/dev/ttyUSB0";
          description = "Coordinator device path; null leaves autodetect";
        };
        mqttBaseTopic = lib.mkOption {
          type = lib.types.str;
          default = "zigbee2mqtt";
          description = "MQTT base topic zigbee2mqtt publishes under";
        };
        permitJoin = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Permit pairing new Zigbee devices; keep off after pairing";
        };
      };

      esphome = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Run upstream services.esphome dashboard (firmware builder)";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 6052;
          description = "ESPHome dashboard HTTP port; 6053 is the device native API, not this";
        };
      };

      zha = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable HA's built-in ZHA integration (needs the zha Python deps and a radio path)";
        };
        radioPath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "/dev/ttyUSB0";
          description = "Radio device for zigpy_config; null configures via UI flow only";
        };
      };

      mqttDevices = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Package name; becomes mqtt-devices/<name>.yaml and the packages key";
            };
            topic = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Base MQTT topic for reference/documentation";
            };
            yaml = lib.mkOption {
              type = lib.types.lines;
              description = "HA YAML snippet (sensor/binary_sensor/etc.) written verbatim into the file";
            };
          };
        });
        default = [];
        example = [
          {
            name = "esp32-kitchen";
            topic = "home/kitchen";
            yaml = "sensor:\n  - name: Kitchen Temperature\n    state_topic: home/kitchen/temp";
          }
        ];
        description = ''
          MQTT device YAML snippets. Each entry lands in
          `configDir/mqtt-devices/<name>.yaml` (via a Nix store symlink) and is
          loaded through `homeassistant.packages.<name> = !include` — the YAML
          must be a complete HA package document.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !dev.zigbee2mqtt.enable || cfg.mqtt.enable;
        message = "services.ha-stack: devices.zigbee2mqtt.enable requires mqtt.enable — zigbee2mqtt publishes through the broker";
      }
    ];
    warnings =
      lib.optional (dupPorts != [])
      "services.ha-stack: duplicate device port(s) ${lib.concatMapStringsSep ", " toString dupPorts} — check services binding the same port";

    services.home-assistant = {
      enable = true;
      inherit (cfg) configDir;
      extraComponents = haComponents;
      extraPackages = ps: cfg.extraPackages ps ++ extraPy ps;
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

        homeassistant = lib.mkIf (dev.mqttDevices != []) {
          packages = lib.listToAttrs (map (
              d: lib.nameValuePair d.name "!include mqtt-devices/${d.name}.yaml"
            )
            dev.mqttDevices);
        };
        zha = lib.mkIf dev.zha.enable (lib.optionalAttrs (dev.zha.radioPath != null) {
          zigpy_config.device.path = dev.zha.radioPath;
        });
      };
    };

    systemd.tmpfiles.rules =
      ["d ${cfg.configDir}/mqtt-devices 0755 - - - -"]
      ++ map (d: "L+ ${cfg.configDir}/mqtt-devices/${d.name}.yaml - - - - ${
        pkgs.writeText "ha-mqtt-${d.name}.yaml" d.yaml
      }")
      dev.mqttDevices;

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

    services.zigbee2mqtt = lib.mkIf dev.zigbee2mqtt.enable {
      enable = true;
      inherit (dev.zigbee2mqtt) dataDir;
      settings = {
        mqtt = {
          base_topic = dev.zigbee2mqtt.mqttBaseTopic;
          server = "mqtt://${cfg.mqtt.address}:${toString cfg.mqtt.port}";
        };
        serial = lib.mkIf (dev.zigbee2mqtt.serialPort != null) {
          port = dev.zigbee2mqtt.serialPort;
        };
        frontend = {
          host = "127.0.0.1";
          port = dev.zigbee2mqtt.port;
        };
        permit_join = dev.zigbee2mqtt.permitJoin;
      };
    };

    services.esphome = lib.mkIf dev.esphome.enable {
      enable = true;
      inherit (dev.esphome) port;
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
