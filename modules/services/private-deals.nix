# Pattern: modules/services/service-portal.nix.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.privateDeals;

  package = pkgs.buildGoModule {
    pname = "private-deals";
    version = "0.2.0";
    src = ./private-deals;
    postPatch = ''
      cp -r ${./fetchcache} ./fetchcache
      chmod -R u+w ./fetchcache
      sed -i 's#\.\./fetchcache#./fetchcache#' go.mod
    '';
    vendorHash = "sha256-rpghWA8x9bNIS9lJe66043jQB4ILV0uTJSDXJByEMZQ=";
    subPackages = ["."];
    env.CGO_ENABLED = 0;
    meta = {
      description = "Private deal, product, watchlist and price-history search service";
      mainProgram = "private-deals";
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
    "${stateDir}/deals.sqlite"
    "-interval"
    cfg.interval
    "-poll-interval"
    cfg.pollInterval
    "-sources"
    (lib.concatStringsSep "," cfg.sources)
    ("-ingest-on-start=" + (bool cfg.ingestOnStart))
    "-rss-feeds"
    (lib.concatStringsSep "," cfg.rssFeeds)
    "-json-feeds"
    (lib.concatStringsSep "," cfg.jsonFeeds)
    "-scrape-urls"
    (lib.concatStringsSep "," cfg.scrapeUrls)
    "-search-queries"
    (lib.concatStringsSep "," cfg.searchQueries)
    "-origin"
    "https://${cfg.tailnetHost}:${toString cfg.tailnetPort}"
    "-fetch-cache-dir"
    "${stateDir}/fetch-cache"
    "-ntfy-url"
    cfg.ntfyUrl
  ];
in {
  options.services.privateDeals = {
    enable = lib.mkEnableOption "the private deals product/watchlist/price-history search service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8102;
      description = "Loopback port the Go service binds. Nothing opens this port in the firewall; the tailnet mount is the whole exposure.";
    };

    tailnetPort = lib.mkOption {
      type = lib.types.port;
      default = 8465;
      description = "Tailnet HTTPS port the servicePortal mount binds. It is part of the write Origin check, so the mount reads this value rather than repeating a literal.";
    };

    tailnetHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "MagicDNS name the portal mount uses. Required because browser writes are accepted only from the tailnet origin.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "private-deals";
      description = "systemd StateDirectory holding deals.sqlite and its WAL.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "private-deals";
      description = "System user owning the service and database.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "6h";
      description = "Go duration between automatic ingestion runs; use 0s to disable the timer.";
    };

    pollInterval = lib.mkOption {
      type = lib.types.str;
      default = "1h";
      description = "Go duration between watchlist polling passes over the configured RSS, JSON, provider-search and scrape sources; use 0s to disable the watchlist ticker.";
    };

    ingestOnStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run one ingestion when the service starts.";
    };

    sources = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["rss" "json-feeds" "web-search" "scrape-urls"];
      description = "Ingestion sources the periodic run executes.";
    };

    rssFeeds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "RSS/Atom deal feeds. Empty means the service's small built-in public feed list; set this option to replace it.";
    };

    jsonFeeds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "JSON endpoints whose deal/item/result/product rows are ingested.";
    };

    scrapeUrls = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Deal pages to scrape through Tavily Extract, Firecrawl Scrape or Context Scrape when credentials exist.";
    };

    searchQueries = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Provider web-search queries. Empty means the service's default deal queries.";
    };

    ntfyUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "ntfy or webhook endpoint used for deduped watchlist price alerts. Prefer PRIVATE_DEALS_NTFY_URL in environmentFile when the URL contains a private topic.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional systemd EnvironmentFile containing FIRECRAWL_API_KEY, TAVILY_API_KEY, CONTEXT_API_KEY and PRIVATE_DEALS_ADMIN_TOKEN. Render it from sops; never put keys in the Nix store.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tailnetHost != null;
        message = "services.privateDeals.tailnetHost is required: POST writes are limited to the configured tailnet origin.";
      }
    ];

    users.groups.${cfg.user} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = stateDir;
      description = "Private deals service";
    };

    systemd.services.private-deals = {
      description = "Private deal, product, watchlist and price-history search service";
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
