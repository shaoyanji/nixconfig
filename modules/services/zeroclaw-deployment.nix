{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.aiServices.zeroclawDeployment;
  aiServicesMounts = import ../lib/ai-services-mounts.nix {inherit lib;};
in {
  imports = [
    ./zeroclaw.nix
  ];

  options.aiServices.zeroclawDeployment =
    {
      enable = lib.mkEnableOption "Fleet-ready zeroclaw host deployment wrapper";

      instanceName = lib.mkOption {
        type = lib.types.str;
        default = "zeroclaw";
        example = "athena";
        description = ''
          Name of the zeroclaw instance. Used to derive the systemd unit
          name (`zeroclaw-<name>.service`), system user/group, and
          state directory. Change this to run multiple agents on one host.
        '';
      };
      mode = lib.mkOption {
        type = lib.types.enum [
          "none"
          "env-file"
          "config-toml"
        ];
        default = "none";
        description = ''
          Secret/config mode for zeroclaw deployment:
          - none: no extra secret/config source is wired
          - env-file: environmentFile must be set
          - config-toml: configTomlSource must be set and staged to <workspaceRoot>/.zeroclaw/config.toml
        '';
      };

      listenHost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "127.0.0.1";
        description = "Host bind address passed to the zeroclaw service.";
      };

      listenPort = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        example = 42617;
        description = "Port passed to the zeroclaw service.";
      };

      workspaceRoot = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/var/lib/zeroclaw";
        description = "State/workspace root for zeroclaw.";
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/run/secrets/zeroclaw";
        description = "Optional environment file consumed by the zeroclaw systemd unit.";
      };

      configTomlSource = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/run/secrets/zeroclaw-config";
        description = "Optional source file copied to the runtime zeroclaw config path before service start.";
      };

      extraSystemPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        example = lib.literalExpression "[ pkgs.curl pkgs.git ]";
        description = ''
          Additional packages to make available in the zeroclaw instance's PATH.
          Useful for exposing system CLIs like curl, git, jq, etc. to skills
          and tools that invoke subprocesses.
        '';
      };

      protectHome = lib.mkOption {
        type = lib.types.either lib.types.bool (lib.types.enum ["read-only" "tmpfs"]);
        default = true;
        description = ''
          Configures ProtectHome= for the zeroclaw systemd unit.
          Set to "read-only" or false to allow subprocesses to read
          home directory configs (e.g. ~/.gitconfig, ~/.ssh/config).
        '';
      };

      bindReadOnlyPaths = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = {};
        example = lib.literalExpression ''
          {
            "/var/lib/zeroclaw/workspace/openclaw" = "/srv/data/openclaw";
          }
        '';
        description = ''
          Read-only bind-mounts to thread into the systemd unit's namespace.
          Map of target = source. Useful for making NAS shares or shared
          data volumes available inside the zeroclaw workspace.
        '';
      };
    }
    // aiServicesMounts.mkMountOptions "zeroclaw";

  config = lib.mkIf cfg.enable {
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
      {
        assertion =
          if cfg.mode == "env-file"
          then cfg.environmentFile != null && cfg.configTomlSource == null
          else true;
        message = "aiServices.zeroclawDeployment mode=env-file requires environmentFile and forbids configTomlSource";
      }
      {
        assertion =
          if cfg.mode == "config-toml"
          then cfg.configTomlSource != null && cfg.environmentFile == null
          else true;
        message = "aiServices.zeroclawDeployment mode=config-toml requires configTomlSource and forbids environmentFile";
      }
      {
        assertion =
          if cfg.mode == "none"
          then cfg.environmentFile == null && cfg.configTomlSource == null
          else true;
        message = "aiServices.zeroclawDeployment mode=none forbids environmentFile and configTomlSource";
      }
    ];

    # Configure the upstream zeroclaw module instance
    services.zeroclaw.instances.${cfg.instanceName} = {
      dataDir = cfg.workspaceRoot;
      environmentFile = cfg.environmentFile;
      extraSystemPackages = cfg.extraSystemPackages;
      protectHome = cfg.protectHome;
      bindReadOnlyPaths = cfg.bindReadOnlyPaths;

      settings = {
        # Bind the gateway to the listenHost and listenPort.
        gateway = {
          host = cfg.listenHost;
          port = cfg.listenPort;
        };
        providers = {
          fallback = "nvidia";
          models = {
            nvidia = {
              wire_api = "chat_completions";
              api_key = "$NVIDIA_API_KEY";
              model = "moonshotai/kimi-k2.6";
            };
            openrouter = {
              wire_api = "chat_completions";
              api_key = "$OPENROUTER_API_KEY";
              base_url = "$OPENROUTER_BASE_URL";
              model = "nvidia/nemotron-3-ultra-550b-a55b:free";
            };
            openai = {
              wire_api = "chat_completions";
              api_key = "$OPENAI_API_KEY";
              base_url = "$OPENAI_BASE_URL";
              model = "$AI_SERVICES_DEFAULT_MODEL";
            };
            deepseek = {
              wire_api = "chat_completions";
              api_key = "$DEEPSEEK_API_KEY";
              base_url = "$DEEPSEEK_BASE_URL";
              model = "deepseek-v4-pro";
            };
          };
        };
      };
    };

    systemd.services."zeroclaw-${cfg.instanceName}" = let
      # Get the mountConfig from aiServicesMounts
      mountConfig = aiServicesMounts.mkMountConfig cfg cfg.workspaceRoot;
    in {
      # Shared defaults that envsubst uses to resolve $VAR refs in settings
      environment = {
        AI_SERVICES_DEFAULT_PROVIDER = "nvidia";
        AI_SERVICES_DEFAULT_MODEL = "moonshotai/kimi-k2.6";
        AI_SERVICES_LOG_LEVEL = "info";
        OPENAI_BASE_URL = "https://aihubmix.com/v1";
        OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1";
        NVIDIA_BASE_URL = "https://integrate.api.nvidia.com/v1";
        OLLAMA_BASE_URL = "http://127.0.0.1:11434";
        DEEPSEEK_BASE_URL = "https://api.deepseek.com/v1";
        FIRECRAWL_API_URL = "https://api.firecrawl.dev/v1";
      };
      serviceConfig = lib.mkMerge [
        mountConfig
        (lib.optionalAttrs (cfg.mode == "config-toml") {
          # Stage the configTomlSource to dataDir/config.toml, replacing the module's envsubst script output
          ExecStartPre = lib.mkForce [
            # Ensure workspace directory exists
            "+${pkgs.coreutils}/bin/mkdir -p ${cfg.workspaceRoot}"
            "+${pkgs.coreutils}/bin/chown zeroclaw-${cfg.instanceName}:zeroclaw-${cfg.instanceName} ${cfg.workspaceRoot}"
            "+${pkgs.coreutils}/bin/chmod 0750 ${cfg.workspaceRoot}"
            # Copy configuration
            "${pkgs.coreutils}/bin/install -m 0600 -o zeroclaw-${cfg.instanceName} -g zeroclaw-${cfg.instanceName} ${cfg.configTomlSource} ${cfg.workspaceRoot}/config.toml"
          ];
        })
      ];
    };
  };
}
