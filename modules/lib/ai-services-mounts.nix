# Reusable helper for AI service modules to add context/auth/state mount options.
# Usage:
#   let
#     aiServicesMounts = import ./lib/ai-services-mounts.nix { inherit lib; };
#   in {
#     options.myService = aiServicesMounts.mkMountOptions "myService";
#     config = lib.mkIf cfg.enable {
#       systemd.services.myservice.serviceConfig = aiServicesMounts.mkMountConfig cfg;
#     };
#   }

{lib}: {
  # Creates the standard set of mount options for an AI service.
  # serviceName should match the name used in aiServices.context.serviceNames.
  mkMountOptions = serviceName: {
    contextRoot = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/srv/data/ai-services/context";
      description = "Optional path to shared read-only context bundle. When set, bind-mounted into service workspace.";
    };

    contextMountPoint = lib.mkOption {
      type = lib.types.str;
      default = ".ai-services/context";
      description = "Relative path within workspaceRoot where context is mounted.";
    };

    sharedDefaultsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/srv/data/ai-services/defaults/shared.env";
      description = "Optional path to shared non-secret defaults env file.";
    };

    sharedSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/ai-services-shared-env";
      description = "Optional path to shared secret env file.";
    };

    stateDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/srv/data/ai-services/state/${serviceName}";
      description = "Optional path to per-service writable state directory.";
    };

    stateMountPoint = lib.mkOption {
      type = lib.types.str;
      default = ".ai-services/state";
      description = "Relative path within workspaceRoot where state dir is mounted.";
    };
  };

  # Creates systemd serviceConfig entries for mounting context/auth/state.
  # cfg should be the service module's config with the mount options above.
  # workspaceRoot should be the service's workspace root path.
  mkMountConfig = cfg: workspaceRoot: let
    contextTarget = "${workspaceRoot}/${cfg.contextMountPoint}";
    stateTarget = "${workspaceRoot}/${cfg.stateMountPoint}";
  in
    {
      # Bind-mount context read-only if configured
      BindReadOnlyPaths = lib.optionals (cfg.contextRoot != null) [
        "${cfg.contextRoot}:${contextTarget}"
      ] ++ lib.optionals (cfg.sharedDefaultsFile != null) [
        "${cfg.sharedDefaultsFile}:${contextTarget}/../defaults/shared.env"
      ];

      # Bind-mount state directory read-write if configured
      BindPaths = lib.optionals (cfg.stateDir != null) [
        "${cfg.stateDir}:${stateTarget}"
      ];

      # Environment files in precedence order:
      # 1. shared defaults (lowest priority)
      # 2. shared secrets (middle priority)
      # 3. service-specific env (highest priority - wins on conflict)
      EnvironmentFile =
        lib.optionals (cfg.sharedDefaultsFile != null) [cfg.sharedDefaultsFile]
        ++ lib.optionals (cfg.sharedSecretFile != null) [cfg.sharedSecretFile];
    };
}
