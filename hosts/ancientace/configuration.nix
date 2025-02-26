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
    ../common/minimal-desktop.nix
  ];
  boot.loader = {
    systemd-boot.enable = lib.mkDefault false;
    grub = {
      device = "/dev/sda";
      enableCryptodisk = true;
      useOSProber = true;
      enable = true;
    };
  };
  networking.hostName = "ancientace"; # Define your hostname.
#  services.xserver.videoDrivers = ["amdgpu"];

  hardware.graphics.extraPackages = [
    pkgs.mesa.opencl
  ];
  system.stateVersion = "24.11"; # Did you read the comment?
  services = {
    displayManager = {
#      sddm = {
#        enable = true;
#        wayland.enable = true;
#      };
      # Enable automatic login for the user.
      autoLogin = {
        enable = true;
        user = "devji";
      };
      #    xserver.digimend.enable = true;
    };
  };
#  programs.hyprland = {
#    enable = true;
#    # set the flake package
#    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
#    # make sure to also set the portal package, so that they are in sync
#    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
#    xwayland.enable = true;
#  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.systemPackages = with pkgs; [
    helix
    vim
    wget
    git
    btrfs-progs
#    kitty
#    ghostty
#    # config.boot.kernelPackages.digimend
  ];
}
