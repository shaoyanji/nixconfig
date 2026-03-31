{
  config,
  lib,
  ...
}: let
  cfg = config.aiServices.context;
in {
  options.aiServices.context = {
    enable = lib.mkEnableOption "AI services shared context materialization";

    sourcePath = lib.mkOption {
      type = lib.types.str;
      default = "/srv/data/nixconfig";
      description = "Repository path to copy context files from.";
    };

    targetPath = lib.mkOption {
      type = lib.types.str;
      default = "/srv/data/ai-services/context";
      description = "Target path for materialized context bundle.";
    };

    defaultsPath = lib.mkOption {
      type = lib.types.str;
      default = "/srv/data/ai-services/defaults";
      description = "Target path for shared non-secret defaults.";
    };

    defaultsFile = lib.mkOption {
      type = lib.types.str;
      default = "/srv/data/ai-services/defaults/shared.env";
      description = "Path to shared non-secret defaults env file.";
    };

    sharedSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/ai-services-shared-env";
      description = "Optional path to shared secret env file.";
    };

    stateRoot = lib.mkOption {
      type = lib.types.str;
      default = "/srv/data/ai-services/state";
      description = "Root path for per-service writable state directories.";
    };

    serviceNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["openclaw" "nullclaw" "hermes" "xs" "openfang"];
      description = "List of service names to create state directories for.";
    };

    contextFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "AGENTS.md"
        ".agents"
      ];
      description = "Relative paths from sourcePath to copy into context bundle.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Activation script to materialize context bundle
    system.activationScripts.ai-services-context = ''
      # Create context directory
      mkdir -p ${cfg.targetPath}
      
      # Copy context files from repo
      ${lib.concatStringsSep "\n" (map (file: ''
        if [ -e "${cfg.sourcePath}/${file}" ]; then
          cp -r "${cfg.sourcePath}/${file}" "${cfg.targetPath}/"
        fi
      '') cfg.contextFiles)}

      # Create defaults directory
      mkdir -p ${cfg.defaultsPath}

      # Create per-service state directories
      ${lib.concatStringsSep "\n" (map (name: ''
        mkdir -p ${cfg.stateRoot}/${name}
        chmod 0750 ${cfg.stateRoot}/${name}
      '') cfg.serviceNames)}
    '';
  };
}
