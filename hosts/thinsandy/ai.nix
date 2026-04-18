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
    ../../modules/profiles/ollama-cloud-defaults.nix
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
    context.enable = true;
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

  services.ollama.enable = true;
}
