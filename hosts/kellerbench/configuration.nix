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
    (import ../../modules/profiles/ai-host.nix {withHermes = false;})
    ../../modules/services/nullclaw-deployment.nix
    inputs.nix-hermes.nixosModules.hermes-agent
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

  nixpkgs.overlays = lib.optionals enableHermes [
    (final: prev: {
      hermes-agent = final.callPackage ../../pkgs/hermes-agent.nix {
        src = inputs.hermes-src;
        version = "main";
      };
    })
  ];

  profiles.aiHost = {
    enable = true;
    nullclaw.enable = true;
    hermes.enable = enableHermes;
  };

  aiServices.nullclawDeployment = {
    enable = true;
    mode = "env-file";
    listenHost = "127.0.0.1";
    listenPort = 3001;
    workspaceRoot = "/var/lib/nullclaw";
    environmentFile = config.sops.secrets.nullclaw.path;
  };

  aiServices.hermesAgent = {
    enable = enableHermes;
    package = pkgs.hermes-agent;
    workspaceRoot = "/var/lib/hermes";
    environmentFile = config.sops.secrets.hermes.path;
  };

  sops.defaultSopsFile = ../../modules/secrets.yaml;

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

  environment.systemPackages = with pkgs; [
    curl
    jq
  ];

  system.stateVersion = "25.05";
}
