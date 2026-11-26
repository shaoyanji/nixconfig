{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.clankerRunner;

  package = pkgs.buildGoModule {
    pname = "clanker-runner";
    version = "0.2.0";
    src = ./clanker-runner;
    vendorHash = "sha256-n+WU7qcF6NauBw9DFU4VG1fnDQ387+nibJ/uzApqehk=";
    env.CGO_ENABLED = 0;
    meta = {
      description = "InstaBox VM, Nix and agent-browser job control plane with SQLite FTS5 history";
      mainProgram = "clanker-runner";
    };
  };

  stateDir = "/var/lib/${cfg.stateDirectory}";
  execArgs = [
    (lib.getExe package)
    "-addr"
    "127.0.0.1:${toString cfg.port}"
    "-db"
    "${stateDir}/clanker-runner.sqlite"
    "-instabox-url"
    (
      if cfg.instaboxUrl == null
      then ""
      else cfg.instaboxUrl
    )
    "-origin"
    "https://${cfg.tailnetHost}:${toString cfg.tailnetPort}"
  ];
in {
  options.services.clankerRunner = {
    enable = lib.mkEnableOption "the InstaBox VM and Nix job control plane";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8104;
      description = "Loopback port the Go service binds. Nothing opens this port in the firewall; the tailnet mount is the whole exposure.";
    };

    tailnetPort = lib.mkOption {
      type = lib.types.port;
      default = 8467;
      description = "Tailnet HTTPS port the servicePortal mount binds. It is part of the write Origin check, so the mount reads this value rather than repeating a literal.";
    };

    tailnetHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "MagicDNS name the portal mount uses. Required because browser writes are accepted only from the tailnet origin.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "clanker-runner";
      description = "systemd StateDirectory holding clanker-runner.sqlite and its WAL.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "clanker-runner";
      description = "System user owning the service and database.";
    };

    instaboxUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional InstaBox API base URL override. Null uses https://api.instabox.sh; tests use a mock httptest URL instead.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional systemd EnvironmentFile containing INSTABOX_API_KEY and CLANKER_RUNNER_ADMIN_TOKEN. Render it from sops; never put keys in the Nix store.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tailnetHost != null;
        message = "services.clankerRunner.tailnetHost is required: POST writes are limited to the configured tailnet origin.";
      }
    ];

    users.groups.${cfg.user} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = stateDir;
      description = "Clanker runner service";
    };

    systemd.services.clanker-runner = {
      description = "InstaBox VM, Nix and agent-browser job control plane";
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
