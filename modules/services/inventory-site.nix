{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.inventorySite;

  package = pkgs.buildGoModule {
    pname = "inventory-site";
    version = "0.2.0";
    src = ./inventory-site;
    vendorHash = "sha256-I3wqEtCYDR8+31GO1eQF5pupapM7q0bDKEzpwfV+rMs=";
    env.CGO_ENABLED = 0;
    meta = {
      description = "Private asset and fleet inventory with SQLite FTS5 search";
      mainProgram = "inventory-site";
    };
  };

  stateDir = "/var/lib/${cfg.stateDirectory}";
  execArgs =
    [
      (lib.getExe package)
      "-addr"
      "127.0.0.1:${toString cfg.port}"
      "-db"
      "${stateDir}/inventory.sqlite"
      "-ntfy-url"
      (
        if cfg.ntfyUrl == null
        then ""
        else cfg.ntfyUrl
      )
      "-warranty-warn-days"
      (toString cfg.warrantyWarnDays)
      "-origin"
      "https://${cfg.tailnetHost}:${toString cfg.tailnetPort}"
    ]
    ++ lib.optionals (cfg.inventorySeedFile != null) [
      "-inventory-seed"
      (toString cfg.inventorySeedFile)
    ];
in {
  options.services.inventorySite = {
    enable = lib.mkEnableOption "the private fleet and personal asset inventory service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8103;
      description = "Loopback port the Go service binds. Nothing opens this port in the firewall; the tailnet mount is the whole exposure.";
    };

    tailnetPort = lib.mkOption {
      type = lib.types.port;
      default = 8466;
      description = "Tailnet HTTPS port the servicePortal mount binds. It is part of the write Origin check, so the mount reads this value rather than repeating a literal.";
    };

    tailnetHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "MagicDNS name the portal mount uses. Required because browser writes are accepted only from the tailnet origin.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "inventory-site";
      description = "systemd StateDirectory holding inventory.sqlite and its WAL.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "inventory-site";
      description = "System user owning the service and database.";
    };

    inventorySeedFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional inventory.toml copied into the closure and imported idempotently at startup as fleet-host asset rows.";
    };

    ntfyUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional ntfy/webhook URL notified once for each asset at a given warranty expiry date. Keep this null or point at a secret-rendered endpoint; the URL is not a secret itself.";
    };

    warrantyWarnDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Number of days before warranty expiry that enters the deduped alert ledger.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional systemd EnvironmentFile containing INVENTORY_SITE_ADMIN_TOKEN or INVENTORY_SITE_NTFY_URL. Render secrets from sops; never put keys in the Nix store.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tailnetHost != null;
        message = "services.inventorySite.tailnetHost is required: POST writes are limited to the configured tailnet origin.";
      }
      {
        assertion = cfg.warrantyWarnDays > 0;
        message = "services.inventorySite.warrantyWarnDays must be positive.";
      }
    ];

    users.groups.${cfg.user} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = stateDir;
      description = "Inventory site service";
    };

    systemd.services.inventory-site = {
      description = "Private fleet and personal asset inventory service";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      unitConfig.X-Fleet-Role = "daemon";
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.user;
        StateDirectory = cfg.stateDirectory;
        StateDirectoryMode = "0750";
        WorkingDirectory = "%S/${cfg.stateDirectory}";
        ExecStart = lib.escapeShellArgs execArgs;
        Environment = ["HOME=${stateDir}"];
        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        Restart = "always";
        RestartSec = 4;
        TimeoutStopSec = 20;
        UMask = "0027";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [stateDir];
        NoNewPrivileges = true;
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
        MemoryMax = "512M";
      };
    };
  };
}
