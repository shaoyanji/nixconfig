# Workspace-share bind mounts for AI services.
# Each enabled service gets its workspace/share directory bind-mounted
# to a shared source, allowing cross-service file access.
#
# Usage:
#   imports = [ ../../modules/services/ai-services-shared-mounts.nix ];
#   aiServices.sharedMounts = {
#     enable = true;
#     source = "/srv/data/openclaw";
#     services.nullclaw = true;
#     services.hermes = true;
#   };
{
  config,
  lib,
  ...
}: let
  cfg = config.aiServices.sharedMounts;

  # Resolve workspaceRoot from each service's config
  workspaceRoots = {
    openclaw = config.aiServices.openclawGateway.workspaceRoot or null;
    nullclaw = config.aiServices.nullclaw.workspaceRoot or null;
    openfang = config.aiServices.openfang.workspaceRoot or null;
    hermes = config.services.hermes-agent.stateDir or null;
  };

  # Mount target paths relative to workspaceRoot
  mountTargets = {
    openclaw = ".openclaw/workspace/share";
    nullclaw = "workspace/share";
    openfang = ".openfang/skills";
    hermes = "workspace/share";
  };

  # Generate fileSystems entries for enabled services
  enabledServiceMounts = lib.filterAttrs (name: enabled:
    enabled
    && workspaceRoots.${name} or null != null
    && cfg.source != null)
  cfg.services;

  generatedFileSystems = lib.mapAttrs' (name: _: let
    root = workspaceRoots.${name};
    target = mountTargets.${name};
  in
    lib.nameValuePair "${root}/${target}" {
      device = cfg.source;
      fsType = "btrfs";
      options = ["bind"];
    })
  enabledServiceMounts;
in {
  options.aiServices.sharedMounts = {
    enable = lib.mkEnableOption "AI services workspace-share bind mounts";

    source = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/srv/data/openclaw";
      description = "Source directory for workspace-share bind mounts.";
    };

    skillsSource = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/srv/data/openclaw/skills/legacy";
      description = "Source directory for openfang skills bind mount (if different from source).";
    };

    services = {
      openclaw = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Mount openclaw workspace/share.";
      };
      nullclaw = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Mount nullclaw workspace/share.";
      };
      openfang = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Mount openfang skills directory.";
      };
      hermes = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Mount hermes workspace/share.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems = generatedFileSystems
      // lib.optionalAttrs (cfg.services.openfang or false && cfg.skillsSource != null) {
        "${workspaceRoots.openfang}/.openfang/skills" = {
          device = cfg.skillsSource;
          fsType = "btrfs";
          options = ["bind"];
        };
      };
  };
}
