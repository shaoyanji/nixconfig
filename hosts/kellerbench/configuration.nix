{ config, lib, pkgs, ... }:
let
  enableSteam = true;
  enableAmdGpu = false;
in
{
  imports =
    [
      (import ../../modules/profiles/grub-boot.nix {
        inherit lib;
        device = "nodev";
      })
      ./hardware-configuration.nix
    ]
    ++ lib.optionals enableAmdGpu [
      ./amd-rx-5700-xt.nix
    ]
    ++ lib.optionals (!enableAmdGpu) [
      ./nvidia-gt-750-ti.nix
    ]
    ++ lib.optionals enableSteam [
      ../../modules/profiles/steamos.nix
    ]
    ++ [
      ../../modules/profiles/base-node.nix
      ../../modules/profiles/ai-host.nix
      # ../../modules/services/hermes-ai-mounts.nix
      ../../modules/services/ai-services-secrets.nix
      ../../modules/services/nullclaw-deployment.nix
      ../../modules/services/ai-services-context.nix
      # inputs.hermes-agent.nixosModules.default
    ];

  networking.hostName = "kellerbench";

  # X server is required by greetd so XWayland can host any legacy
  # X11-only windows that gamescope/Steam spawn. No desktop environment
  # is configured - greetd + tuigreet + gamescope-session is the entire
  # user-facing UI. Gated on enableSteam so enableSteam=false stays
  # headless.
  services.xserver.enable = enableSteam;

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

  # services.ollama = {
  #   enable = true;
  #   # package = if enableAmdGpu then pkgs.ollama-rocm else pkgs.ollama-cuda;
  #   host = "0.0.0.0";
  #   openFirewall = false;
  #   loadModels = [
  #     # "qwen3.5:0.8b"
  #     "nomic-embed-text:latest"
  #   ];
  # };

  environment.systemPackages = with pkgs; [ jq ];

  services.openssh.enable = true;
  system.stateVersion = "25.05";
}
