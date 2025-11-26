{
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    # ../modules/global/minimal.nix
    ../modules/shell
    ../modules/env.nix
    ../modules/nixoshmsymlinks.nix
    ../modules/lf
    ../modules/sops.nix
    ../modules/scripts
    ../modules/aria2.nix
    # ../modules/kitty
    # ../modules/goodies.nix
    # ../modules/helix.nix
  ];
  programs = {
    pay-respects.enable = true;
    nix-your-shell.enable = true;
    atuin.enable = true;

    btop = {
      enable = true;
      settings = {
        color_theme = "tokyo-night.theme";
        theme_background = false;
        vim_keys = true;
      };
    };
    kakoune.enable = true;
    neovim.enable = true;
    # vim.enable = true;
    go = {
      enable = true;
      telemetry.mode = "off";
    };
    uv = {
      enable = true;
      settings = {
        python-downloads = "never";
        python-preference = "only-system";
        pip.index-url = "https://test.pypi.org/simple";
      };
    };
    mpv = {
      enable = true;
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

    yt-dlp = {
      enable = true;
      settings = {
        embed-thumbnail = true;
        embed-subs = true;
        sub-langs = "en";
        downloader = "aria2c";
        downloader-args = "aria2c:'-c -x8 -s8 -k1M'";
      };
    };
    wofi.enable = true;
    # programs.neovide.enable = true;
    # programs.qutebrowser.enable = true;
    # programs.quickshell.enable = true;
    # programs.kitty.enable = true;
    # programs.freetube.enable =true;
    # programs.zed-editor.enable = true;
    #
    translate-shell = {
      enable = true;
      settings = {
        verbose = true;
        hl = "en";
        tl = [
          "zh"
          "de"
        ];
      };
    };
  };
  services = {
    home-manager.autoExpire.enable = true;
  };
  # services.clipmenu.enable = true;
  # services.clipmenu.launcher = "wofi";

  # services.way-displays.enable = true;
  # services.imapnotify={enable=true;
  #   accounts.email.accounts."jisifu".himalaya.enable=true;
  # }
  home = {
    username = "devji";
    homeDirectory = "/home/devji";
    packages = with pkgs; [
      ani-cli
      nix-output-monitor
      lowfi
      duf
      viu
      gum
      go-task
      cloak
      helix
      # wl-clipboard
      ytfzf
      # nixgl.nixGLIntel
    ];
    stateVersion = "24.11";
    file = {
    };
    sessionVariables = {
      EDITOR = "hx";
      invidious_instance = "https://inv.perditum.com";
    };
    sessionPath = [];
  };
  xdg.configFile."systemd/user/cros-garcon.service.d/override.conf".text =
    /*
    ini
    */
    ''
      [Service]
      Environment="PATH=%h/.nix-profile/bin:%h/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/local/games:/usr/sbin:/usr/bin:/usr/games:/sbin:/bin"
      Environment="XDG_DATA_DIRS=%h/.nix-profile/share:%h/.local/share:%h/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"
    '';

  programs.home-manager.enable = true;
}
