# Unified user desktop role (merged home.nix and heim.nix)
# Primary user constants: modules/global/user.nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  user = import ../global/user.nix;
  graphicsTier = config.profiles.graphics.tier or "medium";
in {
  imports = [
    ./minimal.nix
    ../shell
    ../dev.nix
    ../user/ai/antigravity-cli.nix
    ../zen.nix
    ../user/desktop/niri.nix
    ../user/desktop/multimedia.nix
    ../kitty
  ];

  programs = {
    home-manager.enable = true;
    nix-your-shell.enable = true;

    # Gate GPU-heavy Zed editor on hardware tier (GPUI/Vulkan unstable on legacy Haswell/low tier)
    zed-editor.enable = lib.mkDefault (graphicsTier != "low");

    anki = {
      enable = true;
      profiles."User 1".sync = {
        username = "bob";
        url = "http://frieren.lan:27701";
      };
    };

    element-desktop.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;

    obsidian = {
      defaultSettings = {
        app = {
          alwaysUpdateLinks = true;
          vimMode = true;
        };
        appearance = {
          cssTheme = "Nier";
          theme = "obsidian";
        };
        corePlugins = [
          "backlink"
          "bookmarks"
          "canvas"
          "command-palette"
          "daily-notes"
          "editor-status"
          "file-explorer"
          "file-recovery"
          "global-search"
          "graph"
          "note-composer"
          "outgoing-link"
          "outline"
          "page-preview"
          "slides"
          "switcher"
          "tag-pane"
          "templates"
          "word-count"
          "zk-prefixer"
        ];
        communityPlugins = [];
      };
      vaults.local = {
        enable = true;
        target = "/Obsidian Vault";
      };
    };

    ghostty = {
      enable = true;
      themes.catppuccin-mocha = {
        background = "1e1e2e";
        cursor-color = "f5e0dc";
        foreground = "cdd6f4";
        palette = [
          "0=#45475a"
          "1=#f38ba8"
          "2=#a6e3a1"
          "3=#f9e2af"
          "4=#89b4fa"
          "5=#f5c2e7"
          "6=#94e2d5"
          "7=#bac2de"
          "8=#585b70"
          "9=#f38ba8"
          "10=#a6e3a1"
          "11=#f9e2af"
          "12=#89b4fa"
          "13=#f5c2e7"
          "14=#94e2d5"
          "15=#a6adc8"
        ];
        selection-background = "353749";
        selection-foreground = "cdd6f4";
      };
      settings = {
        theme = "catppuccin-mocha";
        font-size = 16;
        font-family = "JetBrainsMono Nerd Font Mono";
        background-opacity = 0.8;
        gtk-titlebar = false;
        keybind = [
          "ctrl+h=goto_split:left"
          "ctrl+l=goto_split:right"
          "ctrl+shift+'=new_split:right"
          "ctrl+shift+enter=new_split:down"
          "ctrl+enter=unbind"
          "ctrl+'=toggle_fullscreen"
          "ctrl+n=new_window"
        ];
      };
    };

    freetube = {
      enable = true;
      settings = {
        # Disable DASH AV1 on low-tier iGPUs (e.g. Haswell HD 4400) to prevent 100% CPU lockups
        allowDashAv1Formats = graphicsTier != "low";
        checkForUpdates = false;
        # Scope default streaming resolution to hardware capability
        defaultQuality =
          if graphicsTier == "low"
          then "720"
          else if graphicsTier == "high"
          then "1440"
          else "1080";
        baseTheme = "catppuccinMocha";
      };
    };
  };

  services = {
    cliphist.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
    caffeine.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
    tailscale-systray.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
  };

  home = {
    username = user.name;
    homeDirectory = user.home;

    packages = with pkgs;
      [
        # ── Moved from base (too heavy for servers) ──
        ffmpeg # Audio/video processing (~1 GB closure)
        viu
        mupdf
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [
        lm_sensors
        ethtool
        iotop
      ]
      ++ lib.optionals stdenv.hostPlatform.isx86_64 [
        hyprpicker
        cliphist
        wl-clipboard
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        iina
        wget
        cocoapods
        m-cli
      ];

    sessionPath = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      "/run/wrappers/bin"
    ];

    sessionVariables = {
      # EDITOR = lib.mkDefault "nvim";
    };
  };
}
