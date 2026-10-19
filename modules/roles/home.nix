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
    # Imported unconditionally (a `pkgs`-dependent import reads `config` and
    # recurses); niri.nix gates its own body with mkIf on Linux, because a
    # Wayland compositor has no aarch64-darwin counterpart and its swayidle
    # dependency is not packaged for darwin — which failed EVALUATION, not just
    # the build, on cassini.
    ../user/desktop/niri.nix
    ../user/desktop/multimedia.nix
    ../user/kg-sidecar.nix
    ../kitty
  ];

  programs = {
    home-manager.enable = true;
    nix-your-shell.enable = true;

    # Keep the knowledge-graph sidecar warm so `kg-query.sh` takes its socket
    # path (it falls back to jq when the socket is absent, so this is a speed
    # setting, not a correctness one).
    kgSidecar.enable = lib.mkDefault true;

    # Gate GPU-heavy Zed editor on hardware tier (GPUI/Vulkan unstable on legacy Haswell/low tier)
    zed-editor.enable = lib.mkDefault (graphicsTier != "low");

    anki = {
      enable = true;
      profiles."User 1".sync = {
        username = "bob";
        url = "http://frieren.lan:27701";
      };
    };

    # element-desktop disabled per debloat standard (unused Matrix client)
    element-desktop.enable = false;

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

    newsboat = {
      enable = true;
      autoReload = true;
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
    wl-clip-persist.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
    udiskie = {
      enable = false;
      tray = "auto";
    };
  };

  systemd.user.services.rclone-gdrive = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Rclone Google Drive FUSE mount";
      Documentation = ["man:rclone(1)"];
      After = ["network-online.target"];
      Wants = ["network-online.target"];
    };

    Service = {
      Type = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/GoogleDrive";
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.rclone}/bin/rclone mount gdrive: %h/GoogleDrive"
        "--vfs-cache-mode=full"
        "--vfs-cache-max-size=10G"
        "--dir-cache-time=72h"
        "--drive-export-formats=link.html"
      ];
      ExecStop = "/run/wrappers/bin/fusermount3 -u %h/GoogleDrive";
      Restart = "on-failure";
      RestartSec = "10s";
      Environment = [
        "PATH=/run/wrappers/bin:/run/current-system/sw/bin:/usr/bin:/bin"
      ];
    };
  };

  home = {
    username = user.name;
    # mkDefault: on darwin the target's own default is /Users/<user>, and two
    # normal-tier definitions conflict (cassini failed its host gate on exactly
    # that). Linux has no competing definition, so the value still applies.
    homeDirectory = lib.mkDefault user.home;

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
