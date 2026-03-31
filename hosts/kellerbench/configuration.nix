{
  config,
  lib,
  pkgs,
  inputs,
  self,
  ...
}: let
  enableHermes = true;
in {
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
    (import ../../modules/profiles/ai-host.nix {})
    ../../modules/services/nullclaw-deployment.nix
    ../../modules/services/ai-services-context.nix
    inputs.hermes-agent.nixosModules.default
  ];

  networking.hostName = "kellerbench";

  home-manager.users.devji.home = {
    username = lib.mkForce "devji";
    homeDirectory = lib.mkForce "/home/devji";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    openFirewall = true;
  };

  users.groups.devji = {};
  users.users.devji = {
    isNormalUser = lib.mkForce true;
    group = lib.mkForce "devji";
  };

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

  services.hermes-agent = {
    enable = enableHermes;
    package = inputs.hermes-agent.packages.${pkgs.system}.default.overrideAttrs (old: {
      version = "0.6.0";
    });
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
        "/srv/data/ai-services/defaults/shared.env:/var/lib/hermes/.ai-services/defaults/shared.env"
      ];
      BindPaths = [
        "/srv/data/ai-services/state/hermes:/var/lib/hermes/.ai-services/state"
      ];
      EnvironmentFile = [
        "/srv/data/ai-services/defaults/shared.env"
      ] ++ config.services.hermes-agent.environmentFiles;
    };

  sops.defaultSopsFile = ../../modules/secrets.yaml;

  sops.secrets.hermes = {
    owner = "hermes";
    group = "hermes";
    mode = "0400";
  };

  services.ollama = {
    enable = true;
    # Keep Ollama local-first; this node is for constrained benchmark runs, not public serving.
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
    curl
    jq
  ];

  system.stateVersion = "25.05";
}
