# private-deals: SQLite/FTS5 deals and price history on the tailnet; the Go
# service beside this file is shaped like modules/services/agent-turns.nix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.private-deals;

  serverPackage = pkgs.buildGoModule {
    pname = "private-deals";
    version = "0.1.0";
    src = ./private-deals;
    vendorHash = "sha256-n+WU7qcF6NauBw9DFU4VG1fnDQ387+nibJ/uzApqehk=";
    env.CGO_ENABLED = 0;
    meta = {
      description = "Deals, watchlists and price history: SQLite/FTS5, RSS ingestion, tailnet API and UI";
      mainProgram = "private-deals";
    };
  };

  stateDir = "/var/lib/${cfg.stateDirectory}";
in {
  options.services.private-deals = {
    enable = lib.mkEnableOption "private-deals: deals, watchlists and price history on this host's tailnet";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8100;
      description = ''
        Loopback port the service listens on. The tailnet mount proxies it; this
        service never binds a public or tailnet address itself.
      '';
    };

    tailnetPort = lib.mkOption {
      type = lib.types.port;
      default = 8464;
      description = ''
        The `tailscale serve` port the mount binds. It is not the loopback port:
        the browser's Origin is `https://<tailnetHost>:<this>`, and the portal
        mount reads this option so the two cannot disagree.
      '';
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "private-deals";
      description = "systemd StateDirectory holding the SQLite database.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "private-deals";
      description = "System user that owns the database and the service.";
    };

    ingestInterval = lib.mkOption {
      type = lib.types.str;
      default = "*:0/30";
      description = "systemd calendar for the feed ingestion pass; empty string disables the timer.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.user} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = stateDir;
      description = "private-deals store";
    };

    systemd.services.private-deals = {
      description = "private-deals API and UI (loopback; deals, watchlists, price history)";
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
        ExecStart = "${lib.getExe serverPackage} serve -addr 127.0.0.1:${toString cfg.port} -db ${stateDir}/deals.db";
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

    systemd.services.private-deals-ingest = lib.mkIf (cfg.ingestInterval != "") {
      description = "Walk the registered private-deals feeds once";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.user;
        ExecStart = "${lib.getExe serverPackage} ingest -db ${stateDir}/deals.db";
        TimeoutStartSec = 120;
        UMask = "0027";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [stateDir];
        NoNewPrivileges = true;
      };
    };

    systemd.timers.private-deals-ingest = lib.mkIf (cfg.ingestInterval != "") {
      description = "Keep private-deals within half an hour of its feeds";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "3min";
        OnCalendar = cfg.ingestInterval;
        Persistent = false;
        RandomizedDelaySec = "60s";
      };
    };
  };
}
