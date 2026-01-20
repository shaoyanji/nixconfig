{
  inputs,
  pkgs,
  config,
  ...
}: {
  imports = [
    ../zen.nix
    ./home.nix
    # ../caelestia.nix
    # ../hypr
    # ../hypr/waybar.nix
    ../niri.nix
    ../dev.nix
    ../kitty
  ];
  programs = {
    zed-editor.enable = true;
    zed-editor.package = pkgs.zed-editor-fhs_git;
    anki = {
      enable = true;
      sync = {
        username = "bob";
        url = "http://thinsandy.fritz.box:27701";
      };
    };
    # quickshell.enable = true;
    element-desktop.enable = true;

    qutebrowser.enable = true;
    onedrive.enable = true;
    obsidian = {
      enable = true;
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
          # "bases"
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
        communityPlugins = [
          # "obsidian-git"
          # "obsidian-excalidraw-plugin"
          # "edit-gemini"
          # "table-editor-obsidian"
          # "dataview"
          # "qmd-as-md-obsidian"
          # "solve"
          # "smart-second-brain"
          # "obsidian-linter"
          # "obsidian-markdown-file-suffix"
          # "templater-obsidian"
          # "numerals"
          # "obsidian-vimrc-support"
        ];
      };
      vaults = {
        #   "personal" = {
        #     enable = true;
        #     target = "/vaults/personal";
        #   };
        #   "work" = {
        #     enable = true;
        #     target = "/vaults/work";
        #   };
        "local" = {
          enable = true;
          target = "/Obsidian Vault";
        };
      };
    };
    ghostty = {
      enable = true;
      themes = {
        catppuccin-mocha = {
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
        allowDashAv1Formats = true;
        checkForUpdates = false;
        defaultQuality = "1080";
        baseTheme = "catppuccinMocha";
      };
    };
  };
  services = {
    cliphist.enable = true;
    caffeine.enable = true;
    dropbox.enable = true;
    tailscale-systray.enable = true;
  };
  home = {
    username = "devji";
    homeDirectory = "/home/devji";
    packages = with pkgs;
      [
      ]
      ++ lib.optionals stdenv.isLinux [
      ]
      ++ lib.optionals stdenv.hostPlatform.isx86_64 [
      ]
      ++ lib.optionals stdenv.hostPlatform.isAarch64 [
      ];
  };
}
