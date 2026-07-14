{
  config,
  lib,
  pkgs,
  ...
}: let
  enableAmdGpu = true;
in {
  imports = [
    (import ../../modules/profiles/grub-boot.nix {
      inherit lib;
      device = "nodev";
    })
    ./hardware-configuration.nix
  ] ++ lib.optionals enableAmdGpu [
    ./amd-rx-5700-xt.nix
  ] ++ lib.optionals (!enableAmdGpu) [
    ./nvidia-gt-750-ti.nix
  ] ++ [
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/ai-host.nix
    ../../modules/services/ai-services-secrets.nix
    ../../modules/services/nullclaw-deployment.nix
    ../../modules/services/ai-services-context.nix
  ];

  networking.hostName = "kellerbench";

  profiles.aiHost = {
    enable = true;
    nullclaw.enable = false;
  };

  aiServices.sharedSecrets.enable = true;

  aiServices = {
    # Enable shared context materialization
    context.enable = true;
    nullclawDeployment = {
      enable = false;
      mode = "env-file";
      listenHost = "127.0.0.1";
      listenPort = 3001;
      workspaceRoot = "/var/lib/nullclaw";
      environmentFile = config.sops.secrets.nullclaw.path;
    };
  };

  services.ollama = {
    enable = true;
    package = if enableAmdGpu then pkgs.ollama-rocm else pkgs.ollama-cuda;
    host = "0.0.0.0";
    openFirewall = false;
    loadModels = [
      # "qwen3.5:0.8b"
      "nomic-embed-text:latest"
    ];
  };

  environment.systemPackages = with pkgs; [
    jq
  ];

  services.openssh.enable = true;
  system.stateVersion = "25.05";
}
