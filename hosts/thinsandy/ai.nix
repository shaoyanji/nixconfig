{
  config,
  pkgs,
  self,
  ...
}: let
  enableHermes = false;
  enableNullClaw = false;
  enableZeroclaw = true;
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
    ../../modules/services/zeroclaw-deployment.nix
    ../../modules/profiles/ai-host.nix
  ];

  profiles.aiHost = {
    enable = true;
    nullclaw.enable = enableNullClaw;
    zeroclaw.enable = enableZeroclaw;
  };

  # aiServices.hermesMounts.enable = enableHermes;
  aiServices.sharedSecrets.enable = true;
  aiServices.sharedMounts = {
    enable = true;
    source = "/srv/data/openclaw";
    services.nullclaw = enableNullClaw;
    services.hermes = enableHermes;
  };

  # --- ZeroClaw ---
  # thinsandy is the NAS host, so data is local — bind mount directly.
  aiServices.zeroclawDeployment = {
    enable = enableZeroclaw;
    instanceName = "athena";
    listenHost = "127.0.0.1";
    listenPort = 42617;
    workspaceRoot = "/var/lib/zeroclaw-athena";
    environmentFile = config.sops.secrets."ai-services-shared-env".path;
    extraEnvironmentFiles = [
      config.sops.templates."zeroclaw-athena-env".path
    ];
    extraSystemPackages = with pkgs; [
      curl
      git
      jq
      skills
    ];
    protectHome = "read-only";
    bindReadOnlyPaths = {
      "/var/lib/zeroclaw-athena/workspace/share" = "/srv/data/openclaw";
    };
    settings = {
      channels.telegram = {
        enabled = true;
        bot_token = "$TELEGRAM_BOT_TOKEN";
        allowed_users = [
          "8522510655"
          "8207284912"
        ];
      };
    };
  };

  sops.secrets.athena-telegram = {
    owner = "zeroclaw-athena";
    group = "zeroclaw-athena";
    mode = "0400";
  };

  sops.templates."zeroclaw-athena-env" = {
    content = ''
      TELEGRAM_BOT_TOKEN=${config.sops.placeholder."athena-telegram"}
    '';
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
      enable = false;
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
