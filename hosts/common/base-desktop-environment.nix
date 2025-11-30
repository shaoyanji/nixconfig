{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    # ./flatpak.nix
    ./minimal-desktop.nix
    ../../modules/nixos/lxc
    # ../../modules/nixos/k3s
  ];
  # Bootloader.
  boot = {
    extraModulePackages = with config.boot.kernelPackages; [v4l2loopback];
    #kernelModules = [
    #  "v4l2loopback"
    #];
    extraModprobeConfig = ''
      options v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
    '';
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  services = {
    displayManager = {
      # sddm = {
      # enable = true;
      # wayland.enable = true;
      # };
      # Enable automatic login for the user.
      autoLogin = {
        enable = true;
        user = "devji";
      };
      #    xserver.digimend.enable = true;
    };
    scx = {
      enable = true;
      scheduler = "scx_rusty";
    };
  };
  # security.polkit.enable = true; # polkit
  # services.gnome.gnome-keyring.enable = true; # secret service
  # security.pam.services.swaylock = {};

  # programs.waybar.enable = true; # top bar

  programs.niri.enable = true;
  programs.niri.package = pkgs.niri_git;
  # programs.hyprland = {
  #   enable = true;
  #   # package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  #   # portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  #   portalPackage = pkgs.xdg-desktop-portal-hyprland;
  #   xwayland.enable = true;
  # };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.systemPackages = with pkgs; [
    lan-mouse_git
    yt-dlp_git
    inkscape
    libreoffice
    hunspell
    hunspellDicts.en_US
    alsa-utils
    # config.boot.kernelPackages.digimend
    #wkhtmltopdf
    #ghostscript
    #        texlive.combined.scheme-full
    #pandoc
    #mods
    #aichat
    #tgpt
    #jekyll
    #bundler
    # scc
    #dog
    # taskwarrior3

    #gitmoji-changelog
    #sparkly-cli
    #lowcharts

    #hare
    #haredoc
    #go
    #cargo
    #tinygo
    # wasmtime
    # luajit
    alsa-utils
    lagrange
    ngrok #unfree
  ];

  programs.appimage = {
    enable = true;
    binfmt = true;
  };
  programs.appimage.package = pkgs.appimage-run.override {
    extraPkgs = pkgs: [
      # missing libraries here, e.g.: `pkgs.libepoxy`
    ];
  };
  # Fonts
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
      #  (pkgs.nerdfonts.override { fonts = ["JetBrainsMono"]; }) # 24.11
    ];
  };
}
