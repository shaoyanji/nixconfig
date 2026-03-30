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

  aiServices.nullclawDeployment = {
    enable = true;
    mode = "env-file";
    listenHost = "127.0.0.1";
    listenPort = 3001;
    workspaceRoot = "/var/lib/nullclaw";
    environmentFile = config.sops.secrets.nullclaw.path;
  };

  services.hermes-agent = {
    enable = enableHermes;
    package = inputs.hermes-agent.packages.${pkgs.system}.default.overrideAttrs (old: {
      version = "0.5.0";
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
      toolsets = [ "all" ];
    };
    environmentFiles = [ config.sops.secrets.hermes.path ];
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

  environment.systemPackages = with pkgs; [
    curl
    jq
  ];

  system.stateVersion = "25.05";
}
