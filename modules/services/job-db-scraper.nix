# Pattern: modules/services/service-portal.nix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.jobDbScraper;

  package = pkgs.buildGoModule {
    pname = "job-db-scraper";
    version = "0.2.0";
    src = ./job-db-scraper;
    postPatch = ''
      cp -r ${./fetchcache} ./fetchcache
      chmod -R u+w ./fetchcache
      sed -i 's#\.\./fetchcache#./fetchcache#' go.mod
    '';
    vendorHash = "sha256-rpghWA8x9bNIS9lJe66043jQB4ILV0uTJSDXJByEMZQ=";
    subPackages = ["."];
    env.CGO_ENABLED = 0;
    meta = {
      description = "Job posting scraper, deduplicator and SQLite FTS5 search service";
      mainProgram = "job-db-scraper";
    };
  };

  stateDir = "/var/lib/${cfg.stateDirectory}";
  bool = value:
    if value
    then "true"
    else "false";
  execArgs = [
    (lib.getExe package)
    "-addr"
    "127.0.0.1:${toString cfg.port}"
    "-db"
    "${stateDir}/jobs.sqlite"
    "-interval"
    cfg.interval
    "-sources"
    (lib.concatStringsSep "," cfg.sources)
    "-scrape-on-start=${bool cfg.scrapeOnStart}"
    "-enrich=${bool cfg.enrich}"
    "-max-enrich"
    (toString cfg.maxEnrich)
    "-ntfy-url"
    (
      if cfg.ntfyUrl == null
      then ""
      else cfg.ntfyUrl
    )
    "-min-alert-score"
    (toString cfg.minAlertScore)
    "-origin"
    "https://${cfg.tailnetHost}:${toString cfg.tailnetPort}"
    "-fetch-cache-dir"
    "${stateDir}/fetch-cache"
  ];
in {
  options.services.jobDbScraper = {
    enable = lib.mkEnableOption "the job database scraper and FTS5 search surface";

    port = lib.mkOption {
      type = lib.types.port;
      # 8094/8095 are media-relay/mataroa and 8100 is the media API on delphi.
      default = 8101;
      description = "Loopback port the Go service binds. Nothing opens this port in the firewall; the tailnet mount is the whole exposure.";
    };

    tailnetPort = lib.mkOption {
      type = lib.types.port;
      # 8463 is appflow; the tailnet mount namespace continues at 8464.
      default = 8464;
      description = "Tailnet HTTPS port the servicePortal mount binds. It is part of the write Origin check, so the mount reads this value rather than repeating a literal.";
    };

    tailnetHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "MagicDNS name the portal mount uses. Required because browser writes are accepted only from the tailnet origin.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "job-db-scraper";
      description = "systemd StateDirectory holding jobs.sqlite and its WAL.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "job-db-scraper";
      description = "System user owning the service and database.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "6h";
      description = "Go duration between automatic scrapes; use 0s to disable the timer.";
    };

    scrapeOnStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run one scrape when the service starts.";
    };

    sources = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["germantechjobs" "weworkremotely" "remoteok" "berlinstartupjobs" "arbeitnow" "web-search"];
      description = "Scrapers the periodic run executes. web-search uses Tavily/Context only when credentials are present.";
    };

    enrich = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enrich thin descriptions through Tavily Extract, Firecrawl Scrape or Context Scrape. Off by default because every call spends provider quota.";
    };

    maxEnrich = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "Maximum enrichment calls per source run.";
    };

    ntfyUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional ntfy/webhook URL notified once for each high-score posting at a given score. Keep this null or point at a secret-rendered endpoint; the URL is not a secret itself.";
    };

    minAlertScore = lib.mkOption {
      type = lib.types.int;
      default = 80;
      description = "Minimum deterministic role-match score, 1 through 100, that causes a posting to enter the alert ledger.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional systemd EnvironmentFile containing FIRECRAWL_API_KEY, TAVILY_API_KEY, CONTEXT_API_KEY, JOB_DB_ADMIN_TOKEN and JOB_DB_NTFY_URL. Render it from sops; never put keys in the Nix store.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tailnetHost != null;
        message = "services.jobDbScraper.tailnetHost is required: POST writes are limited to the configured tailnet origin.";
      }
      {
        assertion = cfg.minAlertScore >= 1 && cfg.minAlertScore <= 100;
        message = "services.jobDbScraper.minAlertScore must be between 1 and 100.";
      }
    ];

    users.groups.${cfg.user} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = stateDir;
      description = "Job database scraper";
    };

    systemd.services.job-db-scraper = {
      description = "Job posting scraper, deduplicator and FTS5 search service";
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
