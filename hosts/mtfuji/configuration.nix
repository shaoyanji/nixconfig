{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common/minimal-desktop.nix
    inputs.nix-openclaw.nixosModules.openclaw-gateway
    inputs.sops-nix.nixosModules.sops
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Use the GRUB 2 boot loader.
  #boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  #boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking.hostName = "mtfuji"; # Define your hostname.
  nixpkgs.overlays = [
    inputs.nix-openclaw.overlays.default
  ];
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  environment.systemPackages = with pkgs; [
    btrfs-progs
    openclaw
    nfs-utils
  ];

  systemd.tmpfiles.rules = [
    "d /srv/data/openclaw 0750 openclaw openclaw - -"
  ];

  fileSystems."/var/lib/openclaw/home" = {
    device = "/srv/data/openclaw";
    options = ["bind"];
  };

  services.openclaw-gateway = {
    enable = true;
    config = {
      gateway = {
        mode = "local";
        # auth.token = "6c8a18065f0676ee763770a195c725c6ee44cc2c5604e10509a45ee3288b0ff6";
      };
    };
    execStartPre = [
      "${pkgs.coreutils}/bin/install -d -o openclaw -g openclaw -m 0750 /var/lib/openclaw"
      "${pkgs.coreutils}/bin/install -o openclaw -g openclaw -m 0600 /etc/openclaw/openclaw.json /var/lib/openclaw/openclaw.json"
    ];

    environmentFiles = [
      config.sops.secrets."openclaw".path
    ];
    environment = {
      # OPENCLAW_CONFIG_PATH = "/var/lib/openclaw/openclaw.json";
      # OPENCLAW_STATE_DIR = "/var/lib/openclaw";
      OPENCLAW_NIX_MODE = "1";
    };
  };

  environment.sessionVariables = {
    OPENCLAW_NIX_MODE = "1";
    # OPENCLAW_GATEWAY_TOKEN = "6c8a18065f0676ee763770a195c725c6ee44cc2c5604e10509a45ee3288b0ff6";
  };

  sops.secrets = {
    openclaw = {
      owner = "openclaw";
      group = "openclaw";
      mode = "0400";
    };
  };
  #powerManagement.powertop.enable = true;
  #virtualisation.docker.enable = true;

  # services.k3s = {
  #   enable = true;
  #   role = "server";
  #   tokenFile = "${config.sops.secrets."local/k3s/token".path}";
  #   clusterInit = true;
  # };
  # networking.firewall.allowedTCPPorts = [
  #   6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
  #   #    2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
  #   #    2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
  # ];

  # networking.firewall.allowedUDPPorts = [
  #   8472 # k3s, flannel: required if using multi-node for inter-node networking
  # ];
  system.stateVersion = "25.05"; # Did you read the comment?
}
