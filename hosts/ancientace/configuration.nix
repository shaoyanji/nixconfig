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
    ../common/laptop.nix

    inputs.chaotic.nixosModules.default
  ];
  home-manager.users.devji.home.sessionVariables.EDITOR = lib.mkForce "nvim";
  boot = {
    kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
  };
  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    efi.canTouchEfiVariables = lib.mkForce false;
    grub = {
      device = "nodev";
      #      enableCryptodisk = true;
      #      useOSProber = true;
      enable = true;
    };
  };
  networking.hostName = "ancientace"; # Define your hostname.
  #services.xserver.videoDrivers = ["amdgpu"];

  hardware.graphics.extraPackages = [
    #    pkgs.mesa.opencl
  ];
  #  system.stateVersion = "24.11"; # Did you read the comment?
  services = {
    displayManager = {
      #     sddm = {
      #      enable = true;
      #     wayland.enable = true;
      #  };
      #    xserver.digimend.enable = true;
    };

    btrfs.autoScrub = {
      enable = true;
      interval = "monthly";
      fileSystems = ["/"];
    };
  };

  environment.systemPackages = with pkgs; [
    btrfs-progs
    f2fs-tools
    #    # config.boot.kernelPackages.digimend
  ];
  services.thermald.enable = true;
}
