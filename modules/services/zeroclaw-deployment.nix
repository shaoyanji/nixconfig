{
  config,
  lib,
  ...
}: let
  cfg = config.aiServices.zeroclawDeployment;
  aiServicesMounts = import ../lib/ai-services-mounts.nix {inherit lib;};
  inherit (lib) mkIf mkOption types optionalAttrs;
in {
  imports = [
    ./zeroclaw.nix
  ];

  options.aiServices.zeroclawDeployment = {
    enable = lib.mkEnableOption "Fleet-ready zeroclaw host deployment wrapper";

    instanceName = mkOption {
      type = types.str;
      default = "zeroclaw";
      description = ''
        Instance name. Derives the systemd unit name
        (`zeroclaw-<name>.service`), system user/group, and
        state directory.
      '';
    };

    listenHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Host bind address for the zeroclaw gateway.";
    };

    listenPort = mkOption {
      type = types.nullOr types.port;
      default = null;
      description = "Port for the zeroclaw gateway.";
    };

    workspaceRoot = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "State/workspace root directory.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Primary environment file loaded by the systemd unit.";
    };

    extraEnvironmentFiles = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["/run/secrets/zeroclaw-telegram"];
      description = ''
        Additional environment files appended with higher priority
        than environmentFile. Use for instance-specific secrets such
        as telegram bot tokens rendered by sops.templates.
      '';
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      example = {
        channels.telegram = {
          enabled = true;
          bot_token = "$TELEGRAM_BOT_TOKEN";
        };
      };
      description = ''
        ZeroClaw config forwarded to
        `services.zeroclaw.instances.<name>.settings`. String values
        may contain `$VAR` references that expand against loaded
        environment files at unit start.

        Provider and model config (API keys, base URLs, model names
        for each provider) should use `$VAR` references to the
        variables provided by environmentFile or extraEnvironmentFiles.
      '';
    };

    extraSystemPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages added to the unit's PATH.";
    };

    protectHome = mkOption {
      type = types.either types.bool (types.enum ["read-only" "tmpfs"]);
      default = true;
      description = "ProtectHome= hardening for the systemd unit.";
    };

    bindReadOnlyPaths = mkOption {
      type = types.attrsOf types.path;
      default = {};
      description = "Read-only bind-mounts (target = source).";
    };
  } // aiServicesMounts.mkMountOptions "zeroclaw";

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.listenHost != null;
        message = "aiServices.zeroclawDeployment.listenHost must be set when enabled";
      }
      {
        assertion = cfg.listenPort != null;
        message = "aiServices.zeroclawDeployment.listenPort must be set when enabled";
      }
      {
        assertion = cfg.workspaceRoot != null;
        message = "aiServices.zeroclawDeployment.workspaceRoot must be set when enabled";
      }
    ];

    # Wire the upstream zeroclaw module instance
    services.zeroclaw.instances.${cfg.instanceName} = {
      dataDir = cfg.workspaceRoot;
      environmentFile = cfg.environmentFile;
      extraSystemPackages = cfg.extraSystemPackages;
      protectHome = cfg.protectHome;
      bindReadOnlyPaths = cfg.bindReadOnlyPaths;
      settings = cfg.settings;
    };

    # Mount shared context/auth/state + append extra env files
    systemd.services."zeroclaw-${cfg.instanceName}" = let
      mountConfig = aiServicesMounts.mkMountConfig cfg cfg.workspaceRoot;
    in {
      serviceConfig = mountConfig
        // optionalAttrs (cfg.extraEnvironmentFiles != []) {
          EnvironmentFile = (mountConfig.EnvironmentFile or []) ++ cfg.extraEnvironmentFiles;
        };
    };
  };
}
