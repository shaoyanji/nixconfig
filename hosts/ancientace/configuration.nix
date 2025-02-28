{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common/base-desktop-environment.nix
  ];
  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    efi.canTouchEfiVariables = lib.mkForce false;
    grub = {
      device = "/dev/sda";
      #      enableCryptodisk = true;
      #      useOSProber = true;
      enable = true;
    };
  };
  networking.hostName = "ancientace"; # Define your hostname.
  services.xserver.videoDrivers = ["amdgpu"];

  hardware.graphics.extraPackages = [
    pkgs.mesa.opencl
  ];
  system.stateVersion = "24.11"; # Did you read the comment?
  services = {
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };
      #    xserver.digimend.enable = true;
    };

    btrfs.autoScrub = {
      enable = true;
      interval = "monthly";
      fileSystems = ["/"];
    };
    k3s = {
      enable = true;
      role = "server"; # Or "agent" for worker only nodes
      tokenFile = "${config.sops.secrets."local/k3s/token".path}";
      serverAddr = "https://thinsandy:6443";
    };
  };
  environment.systemPackages = with pkgs; [
    wget
    git
    btrfs-progs
    #    # config.boot.kernelPackages.digimend
  ];

  zramSwap.enable = true;
}
