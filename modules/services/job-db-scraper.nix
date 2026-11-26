# job-db-scraper: lane-scored postings on the tailnet; shaped like modules/services/agent-turns.nix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.job-db-scraper;

  serverPackage = pkgs.buildGoModule {
    pname = "job-db-scraper";
    version = "0.1.0";
    src = ./job-db-scraper;
    vendorHash = "sha256-n+WU7qcF6NauBw9DFU4VG1fnDQ387+nibJ/uzApqehk=";
    env.CGO_ENABLED = 0;
    meta = {
      description = "Job postings inventory: SQLite/FTS5 with deterministic lane scoring, batch upsert, score-sorted tailnet UI";
      mainProgram = "job-db-scraper";
    };
  };

  stateDir = "/var/lib/${cfg.stateDirectory}";
in {
  options.services.job-db-scraper = {
    enable = lib.mkEnableOption "job-db-scraper: job postings with lane scoring and a score-sorted surface on this host's tailnet";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8102;
      description = "Loopback port; the tailnet mount proxies it, and the service never binds a public or tailnet address itself.";
    };

    tailnetPort = lib.mkOption {
      type = lib.types.port;
      default = 8466;
      description = "The `tailscale serve` port the mount binds; the portal mount reads this option so the two cannot disagree.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "job-db-scraper";
      description = "systemd StateDirectory holding the SQLite database.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "job-db-scraper";
      description = "System user that owns the database and the service.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.user} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = stateDir;
      description = "job-db-scraper store";
    };

    systemd.services.job-db-scraper = {
      description = "job-db-scraper API and UI (loopback; job postings with lane scoring)";
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
        ExecStart = "${lib.getExe serverPackage} serve -addr 127.0.0.1:${toString cfg.port} -db ${stateDir}/jobs.db";
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
