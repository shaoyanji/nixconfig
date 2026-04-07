{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.aiServices.pancakesHarness;
  aiServicesMounts = import ../lib/ai-services-mounts.nix {inherit lib;};
  hasXsModule = config.aiServices ? xs;
  xsCfg =
    if hasXsModule
    then config.aiServices.xs
    else {
      enable = false;
      package = null;
      storePath = "/var/lib/xs/store";
    };
  effectiveXsPackage = if cfg.xsCommandPackage != null then cfg.xsCommandPackage else xsCfg.package;
  effectiveXsAddr = if cfg.xsAddr != null then cfg.xsAddr else "${xsCfg.storePath}/sock";
  envAssignments = attrs:
    lib.mapAttrsToList (name: value: "${name}=${toString value}") attrs;
in {
  options.aiServices.pancakesHarness = {
    enable = lib.mkEnableOption "pancakes-harness service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../pkgs/pancakes-harness.nix {};
      description = "Package providing harness and demo-cli binaries.";
    };

    workspaceRoot = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pancakes-harness";
      description = "Working directory and HOME for the service user.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Optional additional EnvironmentFile paths for the service.";
    };

    bind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address for `harness serve`.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port for `harness serve`.";
    };

    backendMode = lib.mkOption {
      type = lib.types.enum ["xs" "memory"];
      default = "xs";
      description = "Backend mode passed through HARNESS_BACKEND_MODE.";
    };

    xsCommandPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Optional override package supplying the xs binary.";
    };

    xsAddr = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional explicit xs address/socket path; defaults to aiServices.xs.storePath/sock.";
    };

    xsTopicPrefix = lib.mkOption {
      type = lib.types.str;
      default = "pancakes-harness";
      description = "Prefix used by harness xs backend topics.";
    };

    modelMode = lib.mkOption {
      type = lib.types.enum ["mock" "ollama" "http"];
      default = "mock";
      description = "Model adapter mode for harness.";
    };

    modelTimeout = lib.mkOption {
      type = lib.types.str;
      default = "120s";
      description = "HARNESS_MODEL_TIMEOUT value.";
    };

    ollamaEndpoint = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:11434";
      description = "HARNESS_OLLAMA_ENDPOINT value when modelMode=ollama.";
    };

    ollamaModel = lib.mkOption {
      type = lib.types.str;
      default = "qwen3:0.6b";
      description = "HARNESS_OLLAMA_MODEL value when modelMode=ollama.";
    };

    modelEndpoint = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "HARNESS_MODEL_ENDPOINT value when modelMode=http.";
    };

    modelAuthHeader = lib.mkOption {
      type = lib.types.str;
      default = "Authorization";
      description = "HARNESS_MODEL_AUTH_HEADER value when modelMode=http.";
    };

    modelAuthKey = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "HARNESS_MODEL_AUTH_KEY value when modelMode=http.";
    };

    modelBearerToken = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "HARNESS_MODEL_BEARER_TOKEN value when modelMode=http.";
    };
  } // aiServicesMounts.mkMountOptions "pancakes-harness";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.modelMode != "http" || cfg.modelEndpoint != "";
        message = "aiServices.pancakesHarness.modelEndpoint must be set when modelMode=http";
      }
      {
        assertion = cfg.modelMode != "ollama" || cfg.ollamaModel != "";
        message = "aiServices.pancakesHarness.ollamaModel must be set when modelMode=ollama";
      }
      {
        assertion = cfg.backendMode != "xs" || (hasXsModule && xsCfg.enable);
        message = "aiServices.pancakesHarness.backendMode=xs requires modules/services/xs.nix imported with aiServices.xs.enable = true";
      }
      {
        assertion = cfg.backendMode != "xs" || effectiveXsPackage != null;
        message = "aiServices.pancakesHarness.backendMode=xs requires aiServices.xs.package or aiServices.pancakesHarness.xsCommandPackage";
      }
    ];

    users.groups.pancakes-harness = {};

    users.users.pancakes-harness = {
      isSystemUser = true;
      group = "pancakes-harness";
      home = cfg.workspaceRoot;
      createHome = true;
      description = "pancakes-harness service user";
    };

    environment.systemPackages = [cfg.package] ++ lib.optionals (effectiveXsPackage != null) [effectiveXsPackage];

    systemd.tmpfiles.rules = [
      "d ${cfg.workspaceRoot} 0750 pancakes-harness pancakes-harness -"
    ];

    systemd.services.pancakes-harness = let
      mountConfig = aiServicesMounts.mkMountConfig cfg cfg.workspaceRoot;
      sharedEnvFiles = mountConfig.EnvironmentFile or [];
      allEnvFiles = sharedEnvFiles ++ cfg.environmentFiles;
      runtimeEnv = {
        HOME = cfg.workspaceRoot;
        HARNESS_SERVE_BIND = cfg.bind;
        HARNESS_SERVE_PORT = toString cfg.port;
        HARNESS_BACKEND_MODE = cfg.backendMode;
        HARNESS_MODEL_MODE = cfg.modelMode;
        HARNESS_MODEL_TIMEOUT = cfg.modelTimeout;
        HARNESS_OLLAMA_ENDPOINT = cfg.ollamaEndpoint;
        HARNESS_OLLAMA_MODEL = cfg.ollamaModel;
        HARNESS_MODEL_ENDPOINT = cfg.modelEndpoint;
        HARNESS_MODEL_AUTH_HEADER = cfg.modelAuthHeader;
        HARNESS_MODEL_AUTH_KEY = cfg.modelAuthKey;
        HARNESS_MODEL_BEARER_TOKEN = cfg.modelBearerToken;
      } // lib.optionalAttrs (cfg.backendMode == "xs") {
        HARNESS_XS_COMMAND = "${effectiveXsPackage}/bin/xs";
        HARNESS_XS_ADDR = effectiveXsAddr;
        HARNESS_XS_TOPIC_PREFIX = cfg.xsTopicPrefix;
      };
      baseDeps = ["network-online.target"];
      xsDeps = lib.optionals (cfg.backendMode == "xs") ["xs.service"];
    in {
      description = "Pancakes Harness";
      wantedBy = ["multi-user.target"];
      after = baseDeps ++ xsDeps;
      wants = baseDeps ++ xsDeps;
      serviceConfig = {
        User = "pancakes-harness";
        Group = "pancakes-harness";
        WorkingDirectory = cfg.workspaceRoot;
        ExecStart = "${cfg.package}/bin/harness serve";
        Restart = "on-failure";
        RestartSec = "5s";

        Environment = envAssignments runtimeEnv;

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = false;
        ReadWritePaths = [cfg.workspaceRoot];
      } // mountConfig // lib.optionalAttrs (allEnvFiles != []) {
        EnvironmentFile = allEnvFiles;
      };
    };
  };
}
