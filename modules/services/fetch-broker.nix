{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.fetchBroker;

  package = pkgs.buildGoModule {
    pname = "fetch-broker";
    version = "0.1.0";
    src = ./fetch-broker;
    postPatch = ''
      cp -r ${./fetchcache} ./fetchcache
      chmod -R u+w ./fetchcache
      sed -i 's#\.\./fetchcache#./fetchcache#' go.mod
    '';
    subPackages = ["."];
    vendorHash = "sha256-WR3S/9n+CPp9DQnBSuVEwdUpgPXDD2J5tv/0MZT6zjk=";
    env.CGO_ENABLED = 0;
    meta = {
      description = "Lane-aware conditional fetch broker for bulk, US and residential egress";
      mainProgram = "fetch-broker";
    };
  };

  stateDir = "/var/lib/${cfg.stateDirectory}";
  execArgs = [
    (lib.getExe package)
    "-addr"
    "127.0.0.1:${toString cfg.port}"
    "-cache-dir"
    "${stateDir}/fetch-cache"
    "-us-proxy"
    cfg.usProxy
    "-local-proxy"
    cfg.localProxy
    "-render-door"
    cfg.renderDoor
    "-timeout"
    cfg.timeout
    "-max-body-bytes"
    (toString cfg.maxBodyBytes)
  ];
in {
  options.services.fetchBroker = {
    enable = lib.mkEnableOption "the lane-aware fetch broker";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8107;
      description = "Loopback port the Go service binds. Nothing opens this port in the firewall; the tailnet mount is the whole exposure.";
    };

    tailnetPort = lib.mkOption {
      type = lib.types.port;
      default = 8469;
      description = "Tailnet HTTPS port the servicePortal mount binds.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "fetch-broker";
      description = "systemd StateDirectory holding the per-lane conditional fetch caches.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "fetch-broker";
      description = "System user owning the service and cache.";
    };

    timeout = lib.mkOption {
      type = lib.types.str;
      default = "45s";
      description = "Go duration for one upstream fetch, including a lane retry.";
    };

    maxBodyBytes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8388608;
      description = "Maximum body bytes returned or stored for one fetch.";
    };

    usProxy = lib.mkOption {
      type = lib.types.str;
      description = "HTTP/CONNECT proxy URL for the US lane.";
    };

    localProxy = lib.mkOption {
      type = lib.types.str;
      description = "HTTP/CONNECT proxy URL for the residential local lane.";
    };

    renderDoor = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:3002";
      description = "firecrawl-local base URL as reached through the local lane proxy.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.user} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = stateDir;
      description = "Lane-aware fetch broker";
    };

    systemd.services.fetch-broker = {
      description = "Lane-aware conditional fetch broker";
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
