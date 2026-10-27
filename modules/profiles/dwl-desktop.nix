# A dwl session any host can adopt: the layer around the compositor, not a second
# compositor. Keybinds: `modules/config/dwl/config.h`. Launcher:
# `modules/scripts/fleet-menu.sh`. Per-host notes: `.agents/deploy/hosts/`.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.profiles.dwlDesktop;
  fleetMenu = import ../scripts/fleet-menu.nix {inherit pkgs;};

  dwl = pkgs.dwl.override {
    configH = builtins.readFile ../config/dwl/config.h;
  };

  session = pkgs.writeShellApplication {
    name = "dwl-session";
    runtimeInputs =
      [
        pkgs.coreutils
        pkgs.dwl
        pkgs.swayidle
        pkgs.waylock
      ]
      ++ lib.optional (cfg.wallpaper != null) pkgs.swaybg;
    text = builtins.readFile ../config/dwl/dwl-session.sh;
  };

  # The session's knobs are exported in-process rather than through
  # `environment.sessionVariables`, so the session carries its own environment
  # wherever it is launched from.
  sessionCommand = "${
    pkgs.writeShellApplication {
      name = "dwl-session-launch";
      text = ''
        export DWL_WALLPAPER=${lib.escapeShellArg (
          if cfg.wallpaper == null
          then ""
          else cfg.wallpaper
        )}
        exec ${session}/bin/dwl-session "$@"
      '';
    }
  }/bin/dwl-session-launch";
in {
  options.profiles.dwlDesktop = {
    enable = lib.mkEnableOption "a dwl session with launcher and wallpaper";

    user = lib.mkOption {
      type = lib.types.str;
      default = (import ../global/user.nix).name;
      description = "Account the session autologins as.";
    };

    wallpaper = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "#1e1e2e";
      description = ''
        Catppuccin Mocha base as a colour (swaybg -c), an absolute path for an
        image (swaybg -m fill -i), or null for none.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      [
        dwl
        fleetMenu
        pkgs.brightnessctl
        pkgs.foot
        pkgs.grim
        pkgs.imv
        pkgs.mako
        pkgs.playerctl
        pkgs.slurp
        pkgs.wl-clipboard
        pkgs.wmenu
      ]
      ++ lib.optional (cfg.wallpaper != null) pkgs.swaybg;

    # dwl, foot and wmenu name this font; none of them ship it.
    fonts = {
      packages = [pkgs.nerd-fonts.jetbrains-mono];
      fontconfig.defaultFonts.monospace = ["JetBrainsMono Nerd Font Mono" "JetBrainsMono NFM"];
    };

    programs.foot = {
      enable = true;
      theme = "catppuccin-mocha";
      settings = {
        main = {
          font = "JetBrainsMono NFM:size=11";
          pad = "12x12 center";
          dpi-aware = "yes";
        };
        cursor = {
          style = "beam";
          blink = "yes";
        };
        colors-dark.alpha = "0.95";
      };
    };

    programs.appimage = {
      enable = true;
      binfmt = true;
    };

    xdg.portal = {
      enable = lib.mkDefault true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
      config.common.default = lib.mkDefault ["gtk"];
    };

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    security.rtkit.enable = true;
    services.upower.enable = true;
    hardware.graphics.enable = lib.mkDefault true;

    # waylock authenticates through PAM, so it needs a service of its own.
    security.pam.services.waylock = {};

    # No display manager. getty autologins tty1, which gives the session a real
    # logind session (seat, runtime dir, PAM) the way a DM would, and the login
    # shell execs dwl. Measured: SDDM is a Qt stack and greetd + tuigreet were
    # 111 MiB between them, for a machine that logs in one user.
    services.displayManager.sddm.enable = false;
    services.getty.autologinUser = cfg.user;

    # `environment.loginShellInit` is the slot NixOS compiles into /etc/profile
    # (and zsh's equivalent) — /etc/profile.d is NOT read here. Guarded on user,
    # tty and an existing session so ssh, root on the console and a shell inside
    # the desktop are all unaffected.
    environment.loginShellInit = ''
      if [ "$(id -un)" = ${lib.escapeShellArg cfg.user} ] && [ "$(tty)" = /dev/tty1 ] && [ -z "''${WAYLAND_DISPLAY:-}" ]; then
        exec ${sessionCommand}
      fi
    '';
  };
}
