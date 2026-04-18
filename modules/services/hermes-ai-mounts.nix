# Systemd mount overrides for hermes-agent to access shared AI services
# context, defaults, and state directories.
#
# The upstream services.hermes-agent module doesn't support bind mounts
# natively. This module fills that gap using the same ai-services-mounts
# pattern used by nullclaw, xs, openfang, and pancakes-harness.
#
# Usage in host config:
#   imports = [ ../../modules/services/hermes-ai-mounts.nix ];
#   aiServices.hermesMounts.enable = true;
{
  config,
  lib,
  ...
}: let
  cfg = config.aiServices.hermesMounts;
  aiServicesMounts = import ../lib/ai-services-mounts.nix {inherit lib;};
in {
  options.aiServices.hermesMounts = {
    enable = lib.mkEnableOption "Hermes AI services bind mounts (context, state, shared defaults)";

    contextRoot = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "/srv/data/ai-services/context";
      description = "Path to shared read-only context bundle.";
    };

    contextMountPoint = lib.mkOption {
      type = lib.types.str;
      default = ".ai-services/context";
      description = "Relative path within workspaceRoot where context is mounted.";
    };

    sharedDefaultsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "/srv/data/ai-services/defaults/shared.env";
      description = "Path to shared non-secret defaults env file.";
    };

    sharedSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/ai-services-shared-env";
      description = "Optional path to shared secret env file.";
    };

    stateDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "/srv/data/ai-services/state/hermes";
      description = "Path to per-service writable state directory.";
    };

    stateMountPoint = lib.mkOption {
      type = lib.types.str;
      default = ".ai-services/state";
      description = "Relative path within workspaceRoot where state dir is mounted.";
    };
  };

  config = lib.mkIf (cfg.enable && (config.services.hermes-agent.enable or false)) {
    systemd.services.hermes-agent.serviceConfig =
      aiServicesMounts.mkHermesMountConfig cfg config.services.hermes-agent.stateDir
      config.services.hermes-agent.environmentFiles;
  };
}
