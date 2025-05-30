{
  inputs,
  config,
  pkgs,
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
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    # make sure to also set the portal package, so that they are in sync
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
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
    #zed-editor_git
    yt-dlp_git
    libreoffice
    hunspell
    hunspellDicts.en_US
    alsa-utils
    # config.boot.kernelPackages.digimend
  ];
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
  #
  # Fonts
  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
    #  (pkgs.nerdfonts.override { fonts = ["JetBrainsMono"]; })
  ];
}
