{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common/minimal-desktop.nix
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
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  environment.systemPackages = with pkgs; [
    btrfs-progs
    #  f2fs-tools
    #  docker
    #  ethtool
    #  networkd-dispatcher
  ];

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
  system.stateVersion = "24.11"; # Did you read the comment?
}
