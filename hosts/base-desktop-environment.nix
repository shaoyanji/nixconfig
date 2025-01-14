{inputs, config, pkgs, lib, ... }:

{
  imports = [
    ./minimal-desktop.nix
  ];
  # Bootloader.
  boot.loader={
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
  services={
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
  # Enable automatic login for the user.
    displayManager.autoLogin={
      enable = true;
      user = "devji";
    };

    ollama = {
      enable = true;
      acceleration = "cuda";
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
    kitty
    qutebrowser
    libreoffice
    hunspell
    hunspellDicts.en_US
  ];
}
