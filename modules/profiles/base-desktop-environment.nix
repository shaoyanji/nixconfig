{
  pkgs,
  ...
}: {
  imports = [
    ./minimal-desktop.nix
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
  ];

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
