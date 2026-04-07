{
  config,
  lib,
  ...
}: let
  cfg = config.aiServices.context;

  # Helper to check if a service is enabled
  isServiceEnabled = name:
    if name == "openclaw" then config.aiServices.openclawGateway.enable or false
    else if name == "nullclaw" then config.aiServices.nullclaw.enable or false
    else if name == "xs" then config.aiServices.xs.enable or false
    else if name == "openfang" then config.aiServices.openfang.enable or false
    else if name == "pancakes-harness" then (config.aiServices ? pancakesHarness) && (config.aiServices.pancakesHarness.enable or false)
    else if name == "hermes" then config.services.hermes-agent-local.enable or false
    else false;

  # Filter serviceNames to only enabled services
  enabledServices = lib.filter isServiceEnabled cfg.serviceNames;

  # Generate state directory creation commands only for enabled services
  stateDirCommands = lib.concatStringsSep "\n" (map (name: ''
    mkdir -p ${cfg.stateRoot}/${name}
    chown ${cfg.stateOwners.${name}}:${cfg.stateOwners.${name}} ${cfg.stateRoot}/${name}
    chmod 0750 ${cfg.stateRoot}/${name}
  '') enabledServices);
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
      default = ["openclaw" "nullclaw" "hermes" "xs" "openfang" "pancakes-harness"];
      description = "List of service names to create state directories for (only enabled services will be created).";
    };

    stateOwners = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        openclaw = "openclaw";
        nullclaw = "nullclaw";
        hermes = "hermes";
        xs = "xs";
        openfang = "openfang";
        pancakes-harness = "pancakes-harness";
      };
      example = {openclaw = "openclaw"; nullclaw = "nullclaw";};
      description = "AttrSet mapping service name to user owner for state directory.";
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

      # Create defaults directory and shared.env if missing
      mkdir -p ${cfg.defaultsPath}
      if [ ! -f "${cfg.defaultsFile}" ]; then
        cp ${cfg.sourcePath}/modules/services/shared.env.example ${cfg.defaultsFile}
      fi

      # Create per-service state directories with correct ownership (only for enabled services)
      ${stateDirCommands}
    '';
  };
}
