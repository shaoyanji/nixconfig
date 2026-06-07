{
  config,
  pkgs,
  self,
  ...
}: let
  enableHermes = false;
  enableNullClaw = true;
in {
  imports = [
    # ../../modules/services/hermes-ai-mounts.nix
    ../../modules/services/ai-services-secrets.nix
    ../../modules/services/ai-services-shared-mounts.nix
    ../../modules/services/xs.nix
    ../../modules/services/pancakes-harness.nix
    ../../modules/services/ai-services-context.nix
    # inputs.hermes-agent.nixosModules.default
    # ../../modules/profiles/hermes-defaults.nix
    ../../modules/profiles/ollama-cloud-defaults.nix
    ../../modules/profiles/ai-host.nix
  ];

  profiles.aiHost = {
    enable = true;
    nullclaw.enable = enableNullClaw;
  };

  # aiServices.hermesMounts.enable = enableHermes;
  aiServices.sharedSecrets.enable = true;
  aiServices.sharedMounts = {
    enable = true;
    source = "/srv/data/openclaw";
    services.nullclaw = enableNullClaw;
    services.hermes = enableHermes;
  };

  # --- AI Services Configuration ---
  aiServices = {
    context.enable = true;
    nullclaw = {
      enable = enableNullClaw;
      host = "127.0.0.1";
      port = 3001;
      environmentFile = config.sops.secrets."nullclaw".path;
    };
    xs = {
      enable = true;
      package = self.packages.${pkgs.system}.xs;
      storePath = "/var/lib/xs/store";
    };
    pancakesHarness = {
      enable = false;
      package = self.packages.${pkgs.system}.pancakes-harness;
      backendMode = "xs";
      xsTopicPrefix = "pancakes-harness";
      bind = "127.0.0.1";
      port = 8080;
      modelMode = "mock";
    };
  };

  # --- Hermes Agent ---
  # services.hermes-agent = lib.mkIf enableHermes {
  #   enable = true;
  #   environmentFiles = [
  #     config.sops.secrets.hermes.path
  #     config.sops.secrets."ai-services-shared-env".path
  #   ];
  # };

  # --- Hermes secrets (host-specific) ---
  # sops.secrets.hermes = {
  #   owner = "hermes";
  #   group = "hermes";
  #   mode = "0400";
  # };

  services.ollama.enable = true;
}
