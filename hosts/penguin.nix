{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ../modules/roles/portable-home.nix
    ../modules/shell
    ../modules/env.nix
    ../modules/lf
    ../modules/sops.nix
    ../modules/scripts
  ];
  programs = {
    pay-respects.enable = true;
    atuin.enable = true;

    btop = {
      enable = true;
      settings = {
        color_theme = "tokyo-night.theme";
        theme_background = false;
        vim_keys = true;
      };
    };

    mpv = {
      enable = true;
      package = config.lib.nixGL.wrap pkgs.mpv;
      config = {
        profile = "fast";
        hwdec = "auto";
        force-window = true;
      };
      bindings = {
        WHEEL_UP = "seek 10";
        WHEEL_DOWN = "seek -10";
        "Alt+0" = "set window-scale 0.5";
      };
    };
  };
  services = {
    keybase.enable = true;
    home-manager.autoExpire.enable = true;
  };
  home = {
    username = "devji";
    homeDirectory = "/home/devji";
    packages = with pkgs; [
      totp-cli
      nix-output-monitor
      lowfi
      duf
      gum
      go-task
      glow
      cloak
      typst
      tinymist
      pdfcpu
      comrak
      helix
      obs-cli
    ];
    stateVersion = "24.11";
    file = {
      ".local/share/fonts".source = config.lib.file.mkOutOfStoreSymlink "/Volumes/data/dotfiles/.local/share/fonts";
    };
    sessionVariables = {
      EDITOR = "hx";
    };
    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.npm-global/bin"
    ];
  };
  xdg.configFile."systemd/user/cros-garcon.service.d/override.conf".text =
    ''
      [Service]
      Environment="PATH=%h/.nix-profile/bin:%h/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/local/games:/usr/sbin:/usr/bin:/usr/games:/sbin:/bin"
      Environment="XDG_DATA_DIRS=%h/.nix-profile/share:%h/.local/share:%h/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"
    '';
  programs.home-manager.enable = true;
}
