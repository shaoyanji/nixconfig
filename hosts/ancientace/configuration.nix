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
  };
  environment.systemPackages = with pkgs; [
    wget
    git
    btrfs-progs
    #    # config.boot.kernelPackages.digimend
  ];
  zramSwap.enable = true;
}
