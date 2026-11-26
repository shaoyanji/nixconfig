# inventory-site: SQLite/FTS5 asset inventory; shaped like modules/services/agent-turns.nix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.inventory-site;

  serverPackage = pkgs.buildGoModule {
    pname = "inventory-site";
    version = "0.1.0";
    src = ./inventory-site;
    vendorHash = "sha256-n+WU7qcF6NauBw9DFU4VG1fnDQ387+nibJ/uzApqehk=";
    env.CGO_ENABLED = 0;
    meta = {
      description = "Asset inventory: SQLite/FTS5 items with locations, categories, tags, serials, warranties and value; JSON/CSV import-export, tailnet API and UI";
      mainProgram = "inventory-site";
    };
  };

  stateDir = "/var/lib/${cfg.stateDirectory}";

  fleetSeed = pkgs.writeText "inventory-site-hosts.json" (builtins.toJSON (
    lib.mapAttrsToList (name: h: {
      inherit name;
      description = lib.concatStringsSep " — " (builtins.filter (s: s != "") [
        (h.hardware.model or "")
        (h.hardware.cpu or "")
        (h.hardware.ram or "")
      ]);
      tags =
        ["fleet-host"]
        ++ builtins.filter (s: s != "") [
          (h.arch or "")
          (h.category or "")
          (h.role or "")
        ];
      notes = h.notes or "";
    }) (config.fleet.inventory.hosts or {})
  ));
in {
  options.services.inventory-site = {
    enable = lib.mkEnableOption "inventory-site: asset inventory with locations, categories, tags, serials, warranties and value on this host's tailnet";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8101;
      description = ''
        Loopback port the service listens on. The tailnet mount proxies it; this
        service never binds a public or tailnet address itself.
      '';
    };

    tailnetPort = lib.mkOption {
      type = lib.types.port;
      default = 8465;
      description = ''
        The `tailscale serve` port the mount binds. It is not the loopback port:
        the browser's Origin is `https://<tailnetHost>:<this>`, and the portal
        mount reads this option so the two cannot disagree.
      '';
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "inventory-site";
      description = "systemd StateDirectory holding the SQLite database.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "inventory-site";
      description = "System user that owns the database and the service.";
    };

    seedHosts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Seed the fleet's hosts as inventory items when the store is empty at service start.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.user} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = stateDir;
      description = "inventory-site store";
    };

    systemd.services.inventory-site = {
      description = "inventory-site API and UI (loopback; asset inventory)";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      unitConfig = {
        X-Fleet-Role = "daemon";
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.user;
        StateDirectory = cfg.stateDirectory;
        StateDirectoryMode = "0750";
        ExecStart =
          "${lib.getExe serverPackage} serve -addr 127.0.0.1:${toString cfg.port} -db ${stateDir}/inventory.db"
          + lib.optionalString cfg.seedHosts " -seed ${fleetSeed}";
        Restart = "always";
        RestartSec = 5;
        UMask = "0027";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [stateDir];
        NoNewPrivileges = true;
        MemoryMax = "512M";
      };
    };
  };
}
