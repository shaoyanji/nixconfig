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
      ++ lib.optional cfg.bar.enable pkgs.waybar
      ++ lib.optional (cfg.wallpaper != null) pkgs.swaybg;
    text = builtins.readFile ../config/dwl/dwl-session.sh;
  };

  # The session's knobs are exported in-process, not through
  # `environment.sessionVariables`: a greetd session does not necessarily source
  # /etc/profile, so PAM-provided variables are not a guarantee at that point.
  sessionCommand = "${
    pkgs.writeShellApplication {
      name = "dwl-session-launch";
      text = ''
        export DWL_BAR=${
          if cfg.bar.enable
          then "1"
          else "0"
        }
        export DWL_WALLPAPER=${lib.escapeShellArg (
          if cfg.wallpaper == null
          then ""
          else cfg.wallpaper
        )}
        exec ${session}/bin/dwl-session "$@"
      '';
    }
  }/bin/dwl-session-launch";

  tuigreet = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd ${sessionCommand}";
in {
  options.profiles.dwlDesktop = {
    enable = lib.mkEnableOption "a dwl session with launcher, bar and wallpaper";

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

    bar.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run waybar, with the fleet's minimal config from modules/config/waybar.";
    };

    greeter.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Show tuigreet on logout instead of re-entering the session directly.";
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
      ++ lib.optional cfg.bar.enable pkgs.waybar
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

    # A bar config under /etc/xdg is read with or without Home Manager, which is
    # what lets a non-HM host (netbook) share the same bar as an HM one.
    environment.etc = lib.mkIf cfg.bar.enable {
      "xdg/waybar/config.jsonc".source = ../config/waybar/config.jsonc;
      "xdg/waybar/style.css".source = ../config/waybar/style.css;
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

    # One definition: `security.pam.services` twice is a conflict, not a merge.
    security.pam.services = lib.mkMerge [
      {waylock = {};}
      (lib.mkIf config.services.gnome.gnome-keyring.enable {
        greetd.enableGnomeKeyring = true;
      })
    ];

    services.greetd = {
      enable = true;
      settings =
        if cfg.greeter.enable
        then {
          default_session = {
            command = tuigreet;
            user = "greeter";
          };
          initial_session = {
            command = sessionCommand;
            inherit (cfg) user;
          };
        }
        else {
          default_session = {
            command = sessionCommand;
            inherit (cfg) user;
          };
        };
    };
  };
}
