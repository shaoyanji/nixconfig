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
    nullclaw = config.aiServices.nullclaw.workspaceRoot or null;
    hermes = if config.services ? hermes-agent then config.services.hermes-agent.stateDir or null else null;
  };

  # Mount target paths relative to workspaceRoot
  mountTargets = {
    nullclaw = "workspace/share";
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

    services = {
      nullclaw = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Mount nullclaw workspace/share.";
      };
      hermes = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Mount hermes workspace/share.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems = generatedFileSystems;
  };
}
