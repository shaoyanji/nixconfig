# A dwl session any host can adopt: NixOS's `programs.dwl` plus the package and the
# clients. Keybinds `modules/config/dwl/config.h`, launcher `modules/scripts/fleet-menu.sh`,
# host procedure `.agents/deploy/hosts/netbook.md`.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.profiles.dwlDesktop;
  fleetMenu = import ../scripts/fleet-menu.nix {inherit pkgs;};
  appimageMenu = import ../scripts/appimage-menu.nix {inherit pkgs;};

  # Spliced host entries go first, which is what makes them shadow the fleet bind
  # for the same key (`keybinding()` returns the first entry matching mod + keysym).
  # Handed to `programs.dwl.package`, never added to a PATH: see AUDIT.md 2026-10-27.
  dwl = pkgs.dwl.override {
    configH =
      builtins.replaceStrings
      ["/* @EXTRA_KEYBINDS@ */"]
      [cfg.extraKeybinds]
      (builtins.readFile ../config/dwl/config.h);
  };

  wallpaperLine =
    if cfg.wallpaper == null
    then ""
    else if lib.hasPrefix "/" cfg.wallpaper
    then "swaybg -m fill -i ${lib.escapeShellArg cfg.wallpaper} &"
    else "swaybg -c ${lib.escapeShellArg cfg.wallpaper} &";

  # One line per entry, run through sh by name: what resolves them is the PATH
  # this session inherited from the login shell, which home-manager puts
  # ~/.local/bin first on — where a user's own tools live.
  autostartLines = lib.concatMapStringsSep "\n" (cmd: "      sh -c ${lib.escapeShellArg cmd} &") cfg.autostart;

  # dwl publishes WAYLAND_DISPLAY only once its socket exists, and this slot runs
  # before dwl does, so the clients wait for the socket in the background and
  # export the name dwl actually chose: wayland-0 is what libwayland guesses,
  # not what `wl_display_add_socket_auto` promises.
  sessionCommands = ''
    export TERMINAL=foot
    export XDG_SESSION_TYPE=wayland
    export XDG_SESSION_DESKTOP=dwl
    export XDG_CURRENT_DESKTOP=dwl

    (
      for _ in $(seq 1 300); do
        for sock in "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/wayland-*; do
          [ -S "$sock" ] || continue
          export WAYLAND_DISPLAY="''${sock##*/}"
          # The socket FILE outlives the compositor, so the file is only a hint and
          # swayidle — started first, as a client this session needs anyway — is the
          # proof: the set below waits for it to stay up. `.agents/deploy/hosts/netbook.md`
          swayidle -w timeout 600 waylock before-sleep waylock &
          idle=$!
          sleep 0.3
          kill -0 "$idle" 2>/dev/null || continue

          ${wallpaperLine}
    ${autostartLines}
          exit 0
        done
        sleep 0.1
      done
    ) &
  '';
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

    extraKeybinds = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Key[] entries spliced into the shared keymap (modules/config/dwl/config.h)
        at its @EXTRA_KEYBINDS@ marker. They are inserted first, and dwl takes the
        first match, so an entry here shadows the fleet binding for that key.
      '';
    };

    autostart = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Commands the session runs once the Wayland socket exists, with the same
        environment the compositor gets. Entries are shell command lines, and a
        notification daemon belongs here rather than in this profile: which one
        is a host's choice, and two daemons would race for the same bus name.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.dwl = {
      enable = true;
      package = dwl;
      extraSessionCommands = sessionCommands;
    };

    environment.systemPackages =
      [
        fleetMenu
        appimageMenu
        pkgs.brightnessctl
        # The notifier a host's `autostart` starts. It is a package and a
        # baseline config rather than a service because a session daemon has to
        # die with the session; two daemons would race for the bus name.
        pkgs.fnott
        pkgs.foot
        pkgs.grim
        pkgs.imv
        pkgs.playerctl
        pkgs.slurp
        pkgs.swayidle
        pkgs.waylock
        # wl-copy + wtype are the pair a dead-key workaround needs: copy for
        # paste-anywhere, wtype to synthesize the character into the focused window.
        pkgs.wl-clipboard
        pkgs.wmenu
        pkgs.wtype
      ]
      ++ lib.optional (cfg.wallpaper != null) pkgs.swaybg;

    # fnott reads $XDG_CONFIG_HOME/fnott/fnott.ini first and /etc/xdg second, so
    # this is the baseline a host gets for free and a user's own file still wins.
    # The palette is the one this profile already gives foot; there are no
    # per-app sections, because fnott styles by urgency (low/normal/critical).
    environment.etc."xdg/fnott/fnott.ini".text = ''
      title-font=JetBrainsMono Nerd Font:size=11
      summary-font=JetBrainsMono Nerd Font:size=11
      body-font=JetBrainsMono Nerd Font:size=11

      background=1e1e2ef2
      title-color=cdd6f4ff
      summary-color=cdd6f4ff
      body-color=cdd6f4ff

      border-color=89b4faff
      border-size=2
      border-radius=10

      padding-vertical=12
      padding-horizontal=12
      edge-margin-vertical=8
      edge-margin-horizontal=8

      min-width=360
      max-width=440
      max-height=240
      max-icon-size=48

      anchor=top-right
      default-timeout=5

      [low]
      border-color=89b4faff

      [normal]
      border-color=89b4faff

      [critical]
      border-color=f38ba8ff
      default-timeout=0
    '';

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
      # programs.dwl names `wlr` first for this desktop; the closure carries only
      # the gtk portal, so asking for a backend that is not installed buys a
      # warning at every portal start and nothing else.
      config.dwl.default = ["gtk"];
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
    # shell execs `programs.dwl`'s session wrapper. Measured: SDDM is a Qt stack
    # and greetd + tuigreet were 111 MiB between them, for a machine that logs in
    # one user.
    services.displayManager.sddm.enable = false;
    services.getty.autologinUser = cfg.user;

    # `environment.loginShellInit` is the slot NixOS compiles into /etc/profile
    # (and zsh's equivalent) — /etc/profile.d is NOT read here. Guarded on user,
    # tty and an existing session so ssh, root on the console and a shell inside
    # the desktop are all unaffected.
    environment.loginShellInit = ''
      if [ "$(id -un)" = ${lib.escapeShellArg cfg.user} ] && [ "$(tty)" = /dev/tty1 ] && [ -z "''${WAYLAND_DISPLAY:-}" ]; then
        exec /etc/xdg/dwl-session
      fi
    '';
  };
}
