# Fleet monitors as code (HC-6).
#
# Why a module and not Uptime-Kuma monitors: Kuma runs on frieren with **0
# monitors**, so nothing in the fleet is actually watched — not the nightly restic
# job, not the 04:00 `autoUpgrade`, not DNS, not the nginx vhosts. Declaring Kuma's
# monitors in Nix is blocked by the product, not by effort: Kuma 2.5.5's HTTP API
# is read-only (`GET /api/entry-page`, `GET /api/badge/:id/*`) and monitor CRUD
# lives on Socket.IO. Seeding its SQLite DB from Nix is rejected for the same
# reason as seeding Home Assistant's `.storage` (see
# `modules/services/home-assistant.nix`): it is versioned state the application
# owns and rewrites.
#
# So the monitor *definitions* live here as Nix state, and a backend whose
# definition **is** a config file is what consumes them — gatus, through nixpkgs'
# `services.gatus`. Kuma can keep the dashboard for humans.
#
# Endpoints probe `127.0.0.1` by design, so entering one needs no
# `hosts/frieren/firewall-scope.nix` change. The web UI is loopback-only and
# reached through nginx, which is why `openFirewall` defaults to false — a hole
# with only a loopback listener behind it is the REDUNDANT class `checks:ports`
# flags.
{
  config,
  lib,
  ...
}: let
  cfg = config.services.fleetMonitors;

  # gatus requires at least one condition per endpoint. If none are specified,
  # supply type-appropriate defaults based on the URL scheme.
  defaultConditions = url:
    if lib.hasPrefix "tcp://" url
    then ["[CONNECTED] == true"]
    else if lib.hasPrefix "icmp://" url
    then ["[CONNECTED] == true"]
    else ["[STATUS] < 400"];

  toEndpoint = e:
    {
      inherit (e) name url;
      interval =
        if e.interval != null
        then e.interval
        else cfg.interval;
      conditions =
        if e.conditions != null
        then e.conditions
        else defaultConditions e.url;
    }
    // lib.optionalAttrs (e.group != null) {inherit (e) group;};
in {
  options.services.fleetMonitors = {
    enable = lib.mkEnableOption "config-declared fleet monitors (gatus backend)";

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address the monitor UI binds. Loopback by default — reach it through nginx.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8181;
      description = ''
        Port for the monitor UI. Deliberately not `8080`: Pi-hole's web UI already
        owns that on frieren.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open {option}`port` on the firewall. Leave false and proxy it: the backend
        binds loopback, so an opened hole would be unusable (REDUNDANT).
      '';
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "60s";
      description = "Default probe interval for endpoints that do not set their own.";
    };

    endpoints = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Display name of the monitor.";
          };
          url = lib.mkOption {
            type = lib.types.str;
            description = ''
              Target. The URL scheme selects the probe type: `http(s)://` a request,
              `tcp://host:port` a connect, `dns://`, `icmp://host`.
            '';
          };
          enabled = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Include this monitor.";
          };
          group = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Group heading in the UI.";
          };
          interval = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Override {option}`interval` for this monitor.";
          };
          conditions = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default = null;
            description = ''
              gatus conditions (e.g. `["[STATUS] < 400"]`). null lets gatus apply the
              default for the endpoint type.
            '';
          };
        };
      });
      default = [];
      description = ''
        The monitors. Living here is the point of the module: the definition is
        reviewable, diffable state rather than rows in an application database.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.gatus = {
      enable = true;
      inherit (cfg) openFirewall;
      settings = {
        web = {
          inherit (cfg) address port;
        };
        endpoints = map toEndpoint (lib.filter (e: e.enabled) cfg.endpoints);
      };
    };
  };
}
