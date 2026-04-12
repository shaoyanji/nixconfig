{
  config,
  lib,
  pkgs,
  inputs,
  self,
  ...
}: let
  enableHermes = true;
  enableOpenClaw = false;
  enableNullClaw = true;
  enableOpenFang = false;
in {
  imports =
    [
      ../../modules/services/hermes-agent-local.nix
      ../../modules/services/openfang.nix
      ../../modules/services/xs.nix
      ../../modules/services/pancakes-harness.nix
      ../../modules/services/ai-services-context.nix
      inputs.nix-openclaw.nixosModules.openclaw-gateway
      (import ../../modules/profiles/ai-host.nix {
        withOpenclaw = true;
      })
    ]
    ++ lib.optionals enableHermes [
      inputs.hermes-agent.nixosModules.default
    ];

  nixpkgs.overlays =
    []
    ++ lib.optionals enableOpenClaw [
      inputs.nix-openclaw.overlays.default
    ];

  profiles.aiHost = {
    enable = true;
    openclaw.enable = enableOpenClaw;
    nullclaw.enable = enableNullClaw;
  };

  # --- AI Services Configuration ---
  aiServices = {
    # Enable shared context materialization
    context = {
      enable = true;
      serviceNames = ["openclaw" "nullclaw" "hermes" "xs" "openfang" "pancakes-harness"];
    };
    openclawGateway = {
      enable = enableOpenClaw;
      workspaceRoot = "/var/lib/openclaw";
      environmentFile = config.sops.secrets."openclaw".path;
      telegramTokenFile = config.sops.secrets."vanta-telegram".path;
      # Shared context/auth/state mounts
      contextRoot = "/srv/data/ai-services/context";
      sharedDefaultsFile = "/srv/data/ai-services/defaults/shared.env";
      sharedSecretFile = config.sops.secrets."ai-services-shared-env".path or null;
      stateDir = "/srv/data/ai-services/state/openclaw";
    };
    nullclaw = {
      enable = enableNullClaw;
      host = "127.0.0.1";
      port = 3001;
      workspaceRoot = "/var/lib/nullclaw";
      environmentFile = config.sops.secrets."nullclaw".path;
      # Shared context/auth/state mounts
      contextRoot = "/srv/data/ai-services/context";
      sharedDefaultsFile = "/srv/data/ai-services/defaults/shared.env";
      sharedSecretFile = config.sops.secrets."ai-services-shared-env".path or null;
      stateDir = "/srv/data/ai-services/state/nullclaw";
    };
    openfang = {
      enable = enableOpenFang;
      package = self.packages.${pkgs.system}.openfang;
      workspaceRoot = "/var/lib/openfang";
      # Experimental: keep startup inert until the operator adds env vars and
      # completes a manual `openfang init` against the service HOME.
      environmentFile = "/var/lib/openfang/.openfang/openfang.env";
      requireEnvironmentFile = true;
      # Shared context/auth/state mounts
      contextRoot = "/srv/data/ai-services/context";
      sharedDefaultsFile = "/srv/data/ai-services/defaults/shared.env";
      sharedSecretFile = config.sops.secrets."ai-services-shared-env".path or null;
      stateDir = "/srv/data/ai-services/state/openfang";
    };
    xs = {
      enable = true;
      package = self.packages.${pkgs.system}.xs;
      workspaceRoot = "/var/lib/xs";
      storePath = "/var/lib/xs/store";
      # Shared context/auth/state mounts
      contextRoot = "/srv/data/ai-services/context";
      sharedDefaultsFile = "/srv/data/ai-services/defaults/shared.env";
      sharedSecretFile = config.sops.secrets."ai-services-shared-env".path or null;
      stateDir = "/srv/data/ai-services/state/xs";
    };
    pancakesHarness = {
      enable = true;
      package = self.packages.${pkgs.system}.pancakes-harness;
      workspaceRoot = "/var/lib/pancakes-harness";
      backendMode = "xs";
      xsTopicPrefix = "pancakes-harness";
      bind = "127.0.0.1";
      port = 8080;
      modelMode = "mock";
      # Shared context/auth/state mounts
      contextRoot = "/srv/data/ai-services/context";
      sharedDefaultsFile = "/srv/data/ai-services/defaults/shared.env";
      sharedSecretFile = config.sops.secrets."ai-services-shared-env".path or null;
      stateDir = "/srv/data/ai-services/state/pancakes-harness";
    };
  };

  # --- Hermes Agent ---
  services.hermes-agent-local = {
    enable = enableHermes;
    stateDir = "/var/lib/hermes";
    settings = {
      model = {
        # provider = "openrouter";
        # default = "nvidia/nemotron-3-super-120b-a12b:free";
        # context_length = 1000000;
        context_length = 260000;
        provider = "custom";
        # default = "qwen/qwen3.5-397b-a17b";
        default = "minimaxai/minimax-m2.7";
      };
      terminal = {
        backend = "local";
        timeout = 180;
      };
      toolsets = ["all"];
      memory.provider = "holographic";
    };
    environmentFiles = [
      config.sops.secrets.hermes.path
      config.sops.secrets."ai-services-shared-env".path
    ];
  };

  # Host-level override for Hermes to mount shared context/state
  # (upstream module does not support this natively)
  systemd.services.hermes-agent.serviceConfig = {
    BindReadOnlyPaths = [
      "/srv/data/ai-services/context:/var/lib/hermes/.ai-services/context"
      "-/srv/data/ai-services/defaults/shared.env:/var/lib/hermes/.ai-services/defaults/shared.env"
    ];
    BindPaths = [
      "/srv/data/ai-services/state/hermes:/var/lib/hermes/.ai-services/state"
    ];
    EnvironmentFile =
      [
        "-/srv/data/ai-services/defaults/shared.env"
      ]
      ++ config.services.hermes-agent.environmentFiles;
  };

  # --- AI Services Secrets ---
  sops.secrets = lib.mkMerge [
    (lib.mkIf enableNullClaw {
      nullclaw = {
        owner = "nullclaw";
        group = "nullclaw";
        mode = "0400";
      };
    })
    (lib.mkIf enableHermes {
      hermes = {
        owner = "hermes";
        group = "hermes";
        mode = "0400";
      };
    })
    {
      # Shared secrets for all AI services (model API keys, etc.)
      ai-services-shared-env = {
        owner = "root";
        group = "root";
        mode = "0444";
      };
    }
  ];

  # --- AI Services Filesystem Mounts ---
  fileSystems = {
    "/var/lib/openclaw/.openclaw/workspace/share" = {
      device = "/srv/data/openclaw";
      fsType = "btrfs";
      options = ["bind"];
    };
    "/var/lib/openfang/.openfang/skills" = {
      device = "/srv/data/openclaw/skills/legacy";
      fsType = "btrfs";
      options = ["bind"];
    };
    "/var/lib/nullclaw/workspace/share" = {
      device = "/srv/data/openclaw";
      fsType = "btrfs";
      options = ["bind"];
    };
    "/var/lib/hermes/workspace/share" = {
      device = "/srv/data/openclaw";
      fsType = "btrfs";
      options = ["bind"];
    };
  };

  # --- Ollama (AI model serving) ---
  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    openFirewall = true;
    loadModels = [
      "gemma4:31b-cloud"
      "minimax-m2.7:cloud"
      "glm-5.1:cloud"
      "qwen3-coder-next:cloud"
      "kimi-k2.5:cloud"
      "qwen3.5:cloud"
    ];
  };
}
