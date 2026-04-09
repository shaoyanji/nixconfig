{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  enableHermes = true;
in {
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
    ../../modules/profiles/base-node.nix
    (import ../../modules/profiles/ai-host.nix {})
    ../../modules/services/nullclaw-deployment.nix
    ../../modules/services/ai-services-context.nix
    ../../modules/services/hermes-agent-local.nix
    inputs.hermes-agent.nixosModules.default
  ];

  networking.hostName = "kellerbench";

  profiles.aiHost = {
    enable = true;
    nullclaw.enable = true;
  };

  aiServices = {
    # Enable shared context materialization
    context = {
      enable = true;
      serviceNames = ["nullclaw" "hermes"];
    };
    nullclawDeployment = {
      enable = true;
      mode = "env-file";
      listenHost = "127.0.0.1";
      listenPort = 3001;
      workspaceRoot = "/var/lib/nullclaw";
      environmentFile = config.sops.secrets.nullclaw.path;
      # Shared context/auth/state mounts (passed through to nullclaw module)
      contextRoot = "/srv/data/ai-services/context";
      sharedDefaultsFile = "/srv/data/ai-services/defaults/shared.env";
      sharedSecretFile = config.sops.secrets."ai-services-shared-env".path or null;
      stateDir = "/srv/data/ai-services/state/nullclaw";
    };
  };

  services.hermes-agent-local = {
    enable = enableHermes;
    stateDir = "/var/lib/hermes";
    settings = {
      model = {
        provider = "openrouter";
        default = "nvidia/nemotron-3-super-120b-a12b:free";
      };
      terminal = {
        backend = "local";
        timeout = 180;
      };
      toolsets = ["all"];
    };
    environmentFiles = [config.sops.secrets.hermes.path];
  };

  # Host-level override for Hermes to mount shared context/state
  systemd.services.hermes-agent.serviceConfig =
    {
      BindReadOnlyPaths = [
        "/srv/data/ai-services/context:/var/lib/hermes/.ai-services/context"
        "-/srv/data/ai-services/defaults/shared.env:/var/lib/hermes/.ai-services/defaults/shared.env"
      ];
      BindPaths = [
        "/srv/data/ai-services/state/hermes:/var/lib/hermes/.ai-services/state"
      ];
      EnvironmentFile = [
        "-/srv/data/ai-services/defaults/shared.env"
      ] ++ config.services.hermes-agent.environmentFiles;
    };

  sops.secrets.hermes = {
    owner = "hermes";
    group = "hermes";
    mode = "0400";
  };

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    host = "127.0.0.1";
    openFirewall = false;
  };

  sops.secrets.nullclaw = {
    owner = "nullclaw";
    group = "nullclaw";
    mode = "0400";
  };

  # Shared secrets for all AI services
  sops.secrets.ai-services-shared-env = {
    owner = "root";
    group = "root";
    mode = "0444";
  };

  environment.systemPackages = with pkgs; [
    jq
  ];

  system.stateVersion = "25.05";
}
