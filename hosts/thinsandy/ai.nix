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
  imports = [
    ../../modules/services/hermes-ai-mounts.nix
    ../../modules/services/ai-services-secrets.nix
    ../../modules/services/ai-services-shared-mounts.nix
    ../../modules/services/openfang.nix
    ../../modules/services/xs.nix
    ../../modules/services/pancakes-harness.nix
    ../../modules/services/ai-services-context.nix
    inputs.nix-openclaw.nixosModules.openclaw-gateway
    inputs.hermes-agent.nixosModules.default
    ../../modules/profiles/hermes-defaults.nix
    (import ../../modules/profiles/ai-host.nix {
      withOpenclaw = true;
    })
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

  aiServices.hermesMounts.enable = enableHermes;
  aiServices.sharedSecrets.enable = true;
  aiServices.sharedMounts = {
    enable = true;
    source = "/srv/data/openclaw";
    skillsSource = "/srv/data/openclaw/skills/legacy";
    services.openclaw = enableOpenClaw;
    services.nullclaw = enableNullClaw;
    services.openfang = enableOpenFang;
    services.hermes = enableHermes;
  };

  # --- AI Services Configuration ---
  aiServices = {
    context = {
      enable = true;
      serviceNames = ["openclaw" "nullclaw" "hermes" "xs" "openfang" "pancakes-harness"];
    };
    openclawGateway = {
      enable = enableOpenClaw;
      environmentFile = config.sops.secrets."openclaw".path;
      telegramTokenFile = config.sops.secrets."vanta-telegram".path;
    };
    nullclaw = {
      enable = enableNullClaw;
      host = "127.0.0.1";
      port = 3001;
      environmentFile = config.sops.secrets."nullclaw".path;
    };
    openfang = {
      enable = enableOpenFang;
      package = self.packages.${pkgs.system}.openfang;
      environmentFile = "/var/lib/openfang/.openfang/openfang.env";
      requireEnvironmentFile = true;
    };
    xs = {
      enable = true;
      package = self.packages.${pkgs.system}.xs;
      storePath = "/var/lib/xs/store";
    };
    pancakesHarness = {
      enable = true;
      package = self.packages.${pkgs.system}.pancakes-harness;
      backendMode = "xs";
      xsTopicPrefix = "pancakes-harness";
      bind = "127.0.0.1";
      port = 8080;
      modelMode = "mock";
    };
  };

  # --- Hermes Agent ---
  services.hermes-agent = lib.mkIf enableHermes {
    enable = true;
    environmentFiles = [
      config.sops.secrets.hermes.path
      config.sops.secrets."ai-services-shared-env".path
    ];
  };

  # --- Hermes secrets (host-specific) ---
  sops.secrets.hermes = {
    owner = "hermes";
    group = "hermes";
    mode = "0400";
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
