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
    (import ../../modules/profiles/grub-boot.nix {
      inherit lib;
      device = "nodev";
    })
    ./hardware-configuration.nix
    ./nvidia.nix
    ../../modules/profiles/base-node.nix
    (import ../../modules/profiles/ai-host.nix {})
    ../../modules/services/hermes-ai-mounts.nix
    ../../modules/services/ai-services-secrets.nix
    ../../modules/services/nullclaw-deployment.nix
    ../../modules/services/ai-services-context.nix
    inputs.hermes-agent.nixosModules.default
  ];

  networking.hostName = "kellerbench";

  profiles.aiHost = {
    enable = true;
    nullclaw.enable = true;
  };

  aiServices.hermesMounts.enable = enableHermes;
  aiServices.sharedSecrets.enable = true;

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
    };
  };

  services.hermes-agent = lib.mkIf enableHermes {
    enable = true;
    package = inputs.hermes-agent.packages.${pkgs.system}.default;
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

  sops.secrets.hermes = {
    owner = "hermes";
    group = "hermes";
    mode = "0400";
  };

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    host = "0.0.0.0";
    openFirewall = false;
  };

  environment.systemPackages = with pkgs; [
    jq
  ];

  users.users.devji = {
    isNormalUser = true;
    description = "matt";
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [];
  };

  services.openssh.enable = true;
  system.stateVersion = "25.05";
}
