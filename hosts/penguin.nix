{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: {
     nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
             "objectbox-linux"
           ];
         
  imports = [
    # ../modules/global/minimal.nix
    ../modules/shell
    ../modules/env.nix
    ../modules/lf
    ../modules/sops.nix
    ../modules/scripts
    # ../modules/aria2.nix
    # ../modules/dev.nix
    # ../modules/kitty
    # ../modules/goodies.nix
    # ../modules/helix.nix
  ];
  programs = {
    nixvim.enable = true;
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
    # kakoune.enable = true;
    # neovim.enable = true;
    # vim.enable = true;

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

    # yt-dlp = {
    #   enable = true;
    #   settings = {
    #     embed-thumbnail = true;
    #     embed-subs = true;
    #     sub-langs = "en";
    #     downloader = "aria2c";
    #     downloader-args = "aria2c:'-c -x8 -s8 -k1M'";
    #   };
    # };
    # wofi.enable = true;
    # programs.neovide.enable = true;
    # programs.qutebrowser.enable = true;
    # programs.quickshell.enable = true;
    # programs.kitty.enable = true;
    # programs.freetube.enable =true;
    # programs.zed-editor.enable = true;
    #
    #   helix = {
    #     package = pkgs.evil-helix;
    #     enable = true;
    #     languages.language = [
    #       {
    #         name = "bash";
    #         indent = {
    #           tab-width = 4;
    #           unit = "    ";
    #         };
    #         formatter.command = "${pkgs.shfmt}/bin/shfmt";
    #         auto-format = true;
    #       }
    #       {
    #         name = "go";
    #         auto-format = true;
    #         formatter.command = "${pkgs.gopls}/bin/gopls";
    #       }
    #       {
    #         name = "nix";
    #         auto-format = true;
    #         formatter.command = "${pkgs.alejandra}/bin/alejandra";
    #       }
    #     ];

    #     settings = {
    #       theme = "autumn_night_transparent";
    #       editor.default-yank-register = "+";
    #       editor.line-number = "relative";
    #       editor.cursor-shape = {
    #         normal = "block";
    #         insert = "bar";
    #         select = "underline";
    #       };
    #     };
    #     themes = {
    #       autumn_night_transparent = {
    #         "inherits" = "autumn_night";
    #         "ui.background" = {};
    #       };
    #     };
    #   };
  };
  services = {
    # kbfs.enable = true;
    keybase.enable = true;
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
      # mailsy
      totp-cli
      # ani-cli
      nix-output-monitor
      lowfi
      duf
      gum
      go-task
      glow
      cloak
      # mpv
      # ffmpeg
      # yt-dlp
      # wl-clipboard
      # ytfzf
      # nixgl.nixGLIntel
      typst
      tinymist
      pdfcpu
      comrak
      helix
      obs-cli
      # bluebubbles
      # libnotify
    ];
    stateVersion = "24.11";
    file = {
      ".local/share/fonts".source = config.lib.file.mkOutOfStoreSymlink "/Volumes/data/dotfiles/.local/share/fonts";    };
    sessionVariables = {
      EDITOR = "hx";
      # invidious_instance = "https://inv.perditum.com";
      # PATH = "$PATH:$HOME/.local/bin";
    };
#source "/home/devji/.openclaw/completions/openclaw.bash" 
    sessionPath = [ 
	"$HOME/.local/bin"
	"$HOME/.npm-global/bin"
	];
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
  # targets.genericLinux.nixGL = {
  # packages = inputs.nixgl.packages;
  # };
  programs.home-manager.enable = true;
}
