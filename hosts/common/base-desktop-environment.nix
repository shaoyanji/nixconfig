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
    #    ../../modules/nixos/k3s
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
      #      sddm = {
      #       enable = true;
      #      wayland.enable = true;
      #   };
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
      package = pkgs.scx_git.full;
    };
  };
  programs.hyprland = {
    enable = true;
    # set the flake package
    # package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    # make sure to also set the portal package, so that they are in sync
    # portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    xwayland.enable = true;
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.systemPackages = with pkgs; [
    kitty
    ghostty
    inputs.zen-browser.packages.${stdenv.hostPlatform.system}.twilight
    qutebrowser
    lan-mouse_git
    nix-top
    # zed-editor_git
    yt-dlp_git
    libreoffice
    hunspell
    hunspellDicts.en_US
    alsa-utils
    obsidian
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
    element-desktop
    lagrange
    lagrange-tui
    ngrok #unfree
  ];

  programs.thunderbird.enable = true;
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
  #
  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    #  (pkgs.nerdfonts.override { fonts = ["JetBrainsMono"]; }) # 24.11
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "obsidian"
      "ngrok"
    ];
}
