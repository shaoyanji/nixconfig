{
  pkgs,
  lib,
  ...
}:
let
  user = import ../global/user.nix;
in
{
  imports = [
    ./desktop-client.nix
    ../nixos/lxc
    ./boot.nix
  ];

  services = {
    displayManager = {
      autoLogin = {
        enable = true;
        user = user.name;
      };
    };
    scx = {
      enable = true;
      scheduler = "scx_rusty";
    };
  };

  programs.niri.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = "kde";
    XDG_MENU_PREFIX = "plasma-";
  };

  environment.systemPackages = with pkgs; [
    yt-dlp
    lan-mouse
    inkscape
    hunspell
    hunspellDicts.en_US
    alsa-utils
    lagrange
    ngrok
    nautilus
    ffmpegthumbnailer
  ];

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      kdePackages.xdg-desktop-portal-kde
      xdg-desktop-portal-gtk
    ];
    config.common = {
      default = [ "kde" "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "kde" "gtk" ];
    };
    config.niri = lib.mkForce {
      default = [ "kde" "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "kde" "gtk" ];
    };
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  fonts = {
    enableDefaultPackages = true;
    enableGhostscriptFonts = false;
    fontconfig.defaultFonts = {
      serif = ["Noto Serif"];
      sansSerif = ["Noto Sans"];
      monospace = ["JetBrainsMono Nerd Font"];
    };
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
    ];
  };
}
