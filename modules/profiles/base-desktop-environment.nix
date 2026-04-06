{
  pkgs,
  ...
}: {
  imports = [
    ./desktop-client.nix
    ../nixos/lxc
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  services = {
    displayManager = {
      autoLogin = {
        enable = true;
        user = "devji";
      };
    };
    scx = {
      enable = true;
      scheduler = "scx_rusty";
    };
  };

  programs.niri.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.systemPackages = with pkgs; [
    yt-dlp
    lan-mouse
    inkscape
    hunspell
    hunspellDicts.en_US
    alsa-utils
    lagrange
    ngrok
    kdePackages.dolphin
    kdePackages.systemsettings
    kdePackages.ffmpegthumbs
    ffmpegthumbnailer
    xdg-desktop-portal-gtk
    kdePackages.xdg-desktop-portal-kde
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
    config.niri = {
      default = [ "kde" "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "kde" "gtk" ];
    };
  };

  environment.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = "kde";
    XDG_MENU_PREFIX = "plasma-";
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  programs.appimage.package = pkgs.appimage-run.override {
    extraPkgs = pkgs: [
    ];
  };

  fonts = {
    enableDefaultPackages = true;
    enableGhostscriptFonts = true;
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
