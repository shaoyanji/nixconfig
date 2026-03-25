{
  config,
  lib,
  ...
}: let
  cfg = config.aiServices.nullclawDeployment;
in {
  imports = [
    ./nullclaw.nix
  ];

  options.aiServices.nullclawDeployment = {
    enable = lib.mkEnableOption "Fleet-ready nullclaw host deployment wrapper";

    listenHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "127.0.0.1";
      description = "Host bind address passed to the nullclaw service.";
    };

    listenPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      example = 3001;
      description = "Port passed to the nullclaw service.";
    };

    workspaceRoot = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/var/lib/nullclaw";
      description = "State/workspace root for nullclaw.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/nullclaw";
      description = "Optional environment file consumed by the nullclaw systemd unit.";
    };

    configJsonSource = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/nullclaw-config";
      description = "Optional source file copied to the runtime nullclaw config path before service start.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.listenHost != null;
        message = "aiServices.nullclawDeployment.listenHost must be set when enabled";
      }
      {
        assertion = cfg.listenPort != null;
        message = "aiServices.nullclawDeployment.listenPort must be set when enabled";
      }
      {
        assertion = cfg.workspaceRoot != null;
        message = "aiServices.nullclawDeployment.workspaceRoot must be set when enabled";
      }
    ];

    aiServices.nullclaw = {
      enable = true;
      host = cfg.listenHost;
      port = cfg.listenPort;
      workspaceRoot = cfg.workspaceRoot;
      environmentFile = cfg.environmentFile;
    };

    systemd.services.nullclaw.preStart = lib.mkIf (cfg.configJsonSource != null) (lib.mkAfter ''
      install -d -m 0750 -o nullclaw -g nullclaw ${cfg.workspaceRoot}/.nullclaw
      install -m 0400 -o nullclaw -g nullclaw \
        ${cfg.configJsonSource} \
        ${cfg.workspaceRoot}/.nullclaw/config.json
    '');
  };
}
