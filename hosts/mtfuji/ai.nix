{
  config,
  lib,
  pkgs,
  inputs,
  self,
  ...
}: let
  enableNullClaw = true;
  enableOpenClaw = false;
  enableHermes = false;
  enableOpenFang = false;
  enableXS = false;
  enablePancakesHarness = false;
in {
  imports =
    [
      ../../modules/services/nullclaw-deployment.nix
      ../../modules/services/xs.nix
      ../../modules/services/openfang.nix
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
    nullclawDeployment = {
      enable = true;
      mode = "env-file";
      listenHost = "127.0.0.1";
      listenPort = 3001;
      workspaceRoot = "/var/lib/nullclaw";
      environmentFile = config.sops.secrets."nullclaw".path;
    };
    # nullclaw = {
    #   enable = enableNullClaw;
    #   host = "127.0.0.1";
    #   port = 3001;
    #   workspaceRoot = "/var/lib/nullclaw";
    #   environmentFile = config.sops.secrets."nullclaw".path;
    #   # Shared context/auth/state mounts
    #   sharedSecretFile = config.sops.secrets."ai-services-shared-env".path or null;
    # };
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
      enable = enableXS;
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
      enable = enablePancakesHarness;
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
    # Nullclaw workspace mount (moved from hardware-configuration.nix)
    "/var/lib/nullclaw" = {
      device = "/dev/disk/by-uuid/3829936d-db07-4b77-b89a-46a2476578ce";
      fsType = "btrfs";
      options = ["subvol=nix/nullclaw" "compress=zstd" "noatime"];
    };
    "/var/lib/nullclaw/workspace/share" = {
      device = "/srv/data/openclaw";
      fsType = "btrfs";
      options = ["bind"];
    };
  };

  # --- Ollama (AI model serving) ---
  services.ollama = {
    enable = true;
    # acceleration = "cuda";
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
    # models = "/Volumes/data/ollama";
  };
}
