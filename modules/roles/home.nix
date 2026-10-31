# Unified user desktop role (merged home.nix and heim.nix)
{
  config,
  lib,
  pkgs,
  osConfig ? {},
  # Set by `fleet.dankShell.enable` through modules/global/nixos.nix. Default
  # true keeps every darwin/demo/home host on the DMS imports.
  dankShell ? true,
  ...
}: let
  user = import ../global/user.nix;
  graphicsTier = config.profiles.graphics.tier or "medium";
  # Session daemons belong to a generation that declares a compositor:
  # modules/profiles/base-desktop-environment.nix sets `programs.niri.enable`, and
  # frieren's headless boot default never imports it. Enabling them everywhere is
  # what produced services that could only ever fail and be retired.
  sessionEnabled =
    pkgs.stdenv.hostPlatform.isLinux
    && (osConfig.programs.niri.enable or false);
in {
  imports =
    [
      ./minimal.nix
      ../shell
      ../dev.nix
      ../user/ai/antigravity-cli.nix
      ../systemd-policy.nix
      ../zen.nix
      ../user/desktop/multimedia.nix
      ../user/desktop/appimage-menu.nix
      ../user/kg-sidecar.nix
      ../kitty.nix
    ]
    # Imported unconditionally (a `pkgs`-dependent import reads `config` and
    # recurses); niri.nix gates its own body with mkIf on Linux, because a
    # Wayland compositor has no aarch64-darwin counterpart and its swayidle
    # dependency is not packaged for darwin — which failed EVALUATION, not just
    # the build, on cassini. A Ryoku host owns the compositor, so it drops this
    # module rather than redefining the same options twice.
    ++ lib.optionals dankShell [../user/desktop/niri.nix];

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
    cliphist.enable = lib.mkDefault sessionEnabled;
    caffeine.enable = false;
    tailscale-systray.enable = lib.mkDefault sessionEnabled;
    wl-clip-persist.enable = lib.mkDefault sessionEnabled;
    udiskie = {
      enable = false;
      tray = "auto";
    };
  };

  # The session daemons above come from nixpkgs with `Restart=on-failure` and no
  # `RestartSec`, i.e. systemd's 100 ms default: five fast failures at login
  # (no Wayland socket yet, no network) hit the default start limit and retire
  # them for the session. Retry forever with backoff instead of giving up.
  systemd.user.services.cliphist = lib.mkIf sessionEnabled {
    Unit.StartLimitIntervalSec = 0;
    Service = {
      RestartSec = "2s";
      RestartSteps = 5;
      RestartMaxDelaySec = "300s";
    };
  };

  systemd.user.services.cliphist-images = lib.mkIf sessionEnabled {
    Unit.StartLimitIntervalSec = 0;
    Service = {
      RestartSec = "2s";
      RestartSteps = 5;
      RestartMaxDelaySec = "300s";
    };
  };

  systemd.user.services.wl-clip-persist = lib.mkIf sessionEnabled {
    Unit.StartLimitIntervalSec = 0;
    Service = {
      RestartSec = "2s";
      RestartSteps = 5;
      RestartMaxDelaySec = "300s";
    };
  };

  systemd.user.services.rclone-gdrive = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Install.WantedBy = ["default.target"];

    Unit = {
      Description = "Rclone Google Drive FUSE mount";
      Documentation = ["man:rclone(1)"];
      ConditionPathExists = "%h/.config/rclone/rclone.conf";
      After = ["network-online.target"];
      Wants = ["network-online.target"];
      # A resolver that is not up yet must never be able to retire this mount for
      # the rest of the session: never rate-limit the retries below.
      StartLimitIntervalSec = 0;
    };

    Service = {
      Type = "notify";
      TimeoutStartSec = 180;
      # `network-online.target` in a user session is reached well before the
      # resolver answers, so the first OAuth call can die with
      # "lookup oauth2.googleapis.com: no such host" and the mount then sits
      # down. Wait for the name (bounded, ~2 min), then fail loudly so the
      # restart policy tries again instead of mounting nothing.
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p %h/GoogleDrive"
        (pkgs.writeShellScript "rclone-gdrive-wait-dns" ''
          for ((i = 1; i <= 40; i++)); do
            if ${pkgs.getent}/bin/getent hosts oauth2.googleapis.com >/dev/null; then
              exit 0
            fi
            ${pkgs.coreutils}/bin/sleep 3
          done
          echo "rclone-gdrive: oauth2.googleapis.com still unresolvable; letting systemd retry" >&2
          exit 1
        '')
      ];
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.rclone}/bin/rclone mount gdrive: %h/GoogleDrive"
        "--vfs-cache-mode=full"
        "--vfs-cache-max-size=10G"
        "--dir-cache-time=72h"
        "--drive-export-formats=link.html"
      ];
      ExecStop = "/run/wrappers/bin/fusermount3 -u %h/GoogleDrive";
      Restart = "on-failure";
      # 10 s first, backing off to 5 min while the network is out.
      RestartSec = "10s";
      RestartSteps = 5;
      RestartMaxDelaySec = "300s";
      Environment = [
        "PATH=/run/wrappers/bin:/run/current-system/sw/bin:/usr/bin:/bin"
      ];
    };
  };

  xdg.mimeApps = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    enable = true;
    defaultApplications = {
      # Directories / Folders -> Nautilus
      "inode/directory" = ["org.gnome.Nautilus.desktop"];

      # Web & HTML -> Zen Browser
      "text/html" = ["zen-beta.desktop"];
      "x-scheme-handler/http" = ["zen-beta.desktop"];
      "x-scheme-handler/https" = ["zen-beta.desktop"];
      "x-scheme-handler/about" = ["zen-beta.desktop"];
      "x-scheme-handler/unknown" = ["zen-beta.desktop"];
      "x-scheme-handler/chrome" = ["zen-beta.desktop"];
      "application/xhtml+xml" = ["zen-beta.desktop"];
      "application/x-extension-htm" = ["zen-beta.desktop"];
      "application/x-extension-html" = ["zen-beta.desktop"];
      "application/x-extension-shtml" = ["zen-beta.desktop"];
      "application/x-extension-xhtml" = ["zen-beta.desktop"];
      "application/x-extension-xht" = ["zen-beta.desktop"];

      # Custom URL schemes (desktop apps)
      "x-scheme-handler/kando" = ["kando.desktop"];
      "x-scheme-handler/freetube" = ["freetube.desktop"];

      # Documents / PDFs
      "application/pdf" = ["zen-beta.desktop" "mupdf.desktop"];

      # Images -> imv
      "image/png" = ["imv.desktop"];
      "image/jpeg" = ["imv.desktop"];
      "image/gif" = ["imv.desktop"];
      "image/webp" = ["imv.desktop"];
      "image/bmp" = ["imv.desktop"];
      "image/svg+xml" = ["imv.desktop" "zen-beta.desktop"];

      # Audio & Video -> mpv.
      # Wildcards (`video/*`) are NOT MIME types: the XDG spec has no glob
      # matching, so those two lines were silently ignored and every video
      # opened in whatever the desktop guessed. Explicit types are the only
      # form `xdg-mime` honours.
      "video/mp4" = ["mpv.desktop"];
      "video/x-matroska" = ["mpv.desktop"];
      "video/webm" = ["mpv.desktop"];
      "video/quicktime" = ["mpv.desktop"];
      "audio/mpeg" = ["mpv.desktop"];
      "audio/flac" = ["mpv.desktop"];
      "audio/ogg" = ["mpv.desktop"];
      "audio/mp4" = ["mpv.desktop"];
      "audio/x-wav" = ["mpv.desktop"];
    };

    associations.added = {
      # Fallback secondary browsers and handlers from desktop profile
      "x-scheme-handler/http" = ["zen-beta.desktop" "zen-twilight.desktop"];
      "x-scheme-handler/https" = ["zen-beta.desktop" "zen-twilight.desktop"];
      "x-scheme-handler/chrome" = ["zen-beta.desktop" "zen-twilight.desktop"];
      "text/html" = ["zen-twilight.desktop"];
      "application/x-extension-htm" = ["zen-twilight.desktop"];
      "application/x-extension-html" = ["zen-twilight.desktop"];
      "application/x-extension-shtml" = ["zen-twilight.desktop"];
      "application/xhtml+xml" = ["zen-twilight.desktop"];
      "application/x-extension-xhtml" = ["zen-twilight.desktop"];
      "application/x-extension-xht" = ["zen-twilight.desktop"];
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
        imv
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
