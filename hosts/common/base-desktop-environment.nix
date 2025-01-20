{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./flatpak.nix
    ./minimal-desktop.nix
    ../../modules/nixos/lxc
  ];
  # Bootloader.
  boot = {
    extraModulePackages = with config.boot.kernelPackages; [v4l2loopback.out];
    kernelModules = [
      "v4l2loopback"
    ];
    extraModprobeConfig = ''
      options v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
    '';
  };
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
  services = {
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };
      # Enable automatic login for the user.
      autoLogin = {
        enable = true;
        user = "devji";
      };
    };
  };
  programs.hyprland = {
    enable = true;
    # set the flake package
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    # make sure to also set the portal package, so that they are in sync
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    xwayland.enable = true;
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.systemPackages = with pkgs; [
    ffmpeg
    gphoto2
    kitty
    qutebrowser
    libreoffice
    hunspell
    hunspellDicts.en_US
    inputs.ghostty.packages.x86_64-linux.default
    #inputs.zen-browser.packages.${pkgs.system}.twilight
    inputs.zen-browser.packages.${pkgs.system}.default
  ];
}
