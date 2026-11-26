{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.linkVault;

  package = pkgs.buildGoModule {
    pname = "link-vault";
    version = "0.1.0";
    src = ./link-vault;
    vendorHash = "sha256-n+WU7qcF6NauBw9DFU4VG1fnDQ387+nibJ/uzApqehk=";
    env.CGO_ENABLED = 0;
    meta = {
      description = "Bookmark and research link archive with SQLite FTS5 search";
      mainProgram = "link-vault";
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
    "${stateDir}/links.sqlite"
    ("-extract-on-add=" + (bool cfg.extractOnAdd))
    "-origin"
    "https://${cfg.tailnetHost}:${toString cfg.tailnetPort}"
  ];
in {
  options.services.linkVault = {
    enable = lib.mkEnableOption "the bookmark and research link archive service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8106;
      description = "Loopback port the Go service binds. Nothing opens this port in the firewall; the tailnet mount is the whole exposure.";
    };

    tailnetPort = lib.mkOption {
      type = lib.types.port;
      default = 8468;
      description = "Tailnet HTTPS port the servicePortal mount binds. It is part of the write Origin check, so the mount reads this value rather than repeating a literal.";
    };

    tailnetHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "MagicDNS name the portal mount uses. Required because browser writes are accepted only from the tailnet origin.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "link-vault";
      description = "systemd StateDirectory holding links.sqlite and its WAL.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "link-vault";
      description = "System user owning the service and database.";
    };

    extractOnAdd = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Extract readable page text automatically when a newly created link is saved. API callers can still request extraction per link.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional systemd EnvironmentFile containing FIRECRAWL_API_KEY, TAVILY_API_KEY, CONTEXT_API_KEY and LINK_VAULT_ADMIN_TOKEN. Render it from sops; never put keys in the Nix store.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tailnetHost != null;
        message = "services.linkVault.tailnetHost is required: POST writes are limited to the configured tailnet origin.";
      }
    ];

    users.groups.${cfg.user} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = stateDir;
      description = "Link vault service";
    };

    systemd.services.link-vault = {
      description = "Bookmark and research link archive service";
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
