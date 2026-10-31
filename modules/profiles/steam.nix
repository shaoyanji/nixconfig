# Steam: package, gamemode and the 32-bit graphics/audio a game session needs.
{
  pkgs,
  lib,
  ...
}: let
  user = import ../global/user.nix;

  # Graceful session switching between Gamescope (Steam Big Picture)
  # and DankMaterialShell (Niri desktop) on Steam Deck and console hosts.
  deckSessionSwitch = pkgs.writeShellScriptBin "deck-session-switch" ''
    set -euo pipefail

    export PATH="${lib.makeBinPath (with pkgs; [procps coreutils gnugrep systemd])}:\$PATH"

    STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/deck-session"
    STATE_FILE="$STATE_DIR/target-session"
    mkdir -p "$STATE_DIR"

    detect_current_session() {
      if pgrep -x gamescope >/dev/null 2>&1; then
        echo "gamescope"
      elif pgrep -x niri >/dev/null 2>&1; then
        echo "dms"
      else
        echo "unknown"
      fi
    }

    switch_to_desktop() {
      echo "Switching gracefully to DankMaterialShell (Niri Desktop)..."
      echo "dms" > "$STATE_FILE"

      # 1. Gracefully shut down Steam client if running
      if pgrep -x steam >/dev/null 2>&1; then
        echo "Sending shutdown request to Steam (syncing cloud saves)..."
        steam -shutdown 2>/dev/null || pkill -SIGTERM -x steam 2>/dev/null || true

        # Wait up to 10 seconds for Steam to exit cleanly
        for _ in {1..10}; do
          if ! pgrep -x steam >/dev/null 2>&1; then
            echo "Steam exited cleanly."
            break
          fi
          sleep 1
        done
      fi

      # 2. Terminate gamescope compositor if still active
      if pgrep -x gamescope >/dev/null 2>&1; then
        echo "Stopping gamescope micro-compositor..."
        pkill -SIGTERM -x gamescope 2>/dev/null || true
        sleep 1
        if pgrep -x gamescope >/dev/null 2>&1; then
          pkill -SIGKILL -x gamescope 2>/dev/null || true
        fi
      fi

      echo "Gamescope session closed. Returning to DankMaterialShell."
    }

    switch_to_gaming() {
      echo "Switching gracefully to Gamescope (Steam Gaming Mode)..."
      echo "gamescope" > "$STATE_FILE"

      # 1. Gracefully exit Niri (DankMaterialShell compositor)
      if pgrep -x niri >/dev/null 2>&1; then
        echo "Closing Niri compositor session..."
        if command -v niri >/dev/null 2>&1; then
          niri msg action quit --skip-confirmation 2>/dev/null || niri msg action quit 2>/dev/null || true
        fi
        sleep 1
        if pgrep -x niri >/dev/null 2>&1; then
          pkill -SIGTERM -x niri 2>/dev/null || true
        fi
      fi

      # 2. Trigger return to Gamescope via greetd autologin if greetd is active
      if systemctl is-active --quiet greetd.service 2>/dev/null; then
        echo "Restarting greetd to boot into Gamescope initial session..."
        if [ "''${EUID:-$(id -u)}" -eq 0 ]; then
          systemctl restart greetd.service 2>/dev/null || true
        elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
          sudo systemctl restart greetd.service 2>/dev/null || true
        elif [ -x /run/wrappers/bin/sudo ] && /run/wrappers/bin/sudo -n true 2>/dev/null; then
          /run/wrappers/bin/sudo systemctl restart greetd.service 2>/dev/null || true
        fi
      elif ! pgrep -x gamescope >/dev/null 2>&1; then
        # Standalone fallback: launch the gamescope Steam session if in TTY
        if command -v steam-gamescope >/dev/null 2>&1; then
          echo "Launching steam-gamescope directly..."
          exec steam-gamescope
        fi
      fi

      echo "Switched to Gamescope."
    }

    show_status() {
      local current
      current=$(detect_current_session)
      local target="none"
      if [[ -f "$STATE_FILE" ]]; then
        target=$(cat "$STATE_FILE")
      fi

      echo "Deck Session Status:"
      echo "  Active Session: $current"
      echo "  Target Session: $target"
    }

    action="''${1:-toggle}"

    case "$action" in
      desktop|dms|niri|plasma|plasma-wayland-persistent|plasma-x11-persistent)
        switch_to_desktop
        ;;
      gamescope|steam|gaming|gamepadui)
        switch_to_gaming
        ;;
      status|--status|-s)
        show_status
        ;;
      toggle|--toggle)
        current=$(detect_current_session)
        if [[ "$current" == "gamescope" ]]; then
          switch_to_desktop
        else
          switch_to_gaming
        fi
        ;;
      help|--help|-h)
        echo "Usage: $(basename "$0") [desktop|gamescope|status|toggle]"
        echo ""
        echo "Gracefully switch between Gamescope (Steam Big Picture) and DankMaterialShell (Niri Desktop)."
        echo ""
        echo "Actions:"
        echo "  desktop    Switch from Gamescope to DankMaterialShell"
        echo "  gamescope  Switch from DankMaterialShell to Gamescope"
        echo "  toggle     Toggle between active sessions (default)"
        echo "  status     Display active and target session"
        ;;
      *)
        echo "Unknown action: $action"
        echo "Run '$(basename "$0") --help' for usage."
        exit 1
        ;;
    esac
  '';

  # SteamOS compatibility link: Steam Big Picture looks for steamos-session-select
  # when the user triggers "Switch to Desktop" from the Power menu.
  steamosSessionSelect = pkgs.writeShellScriptBin "steamos-session-select" ''
    exec ${deckSessionSwitch}/bin/deck-session-switch "$@"
  '';

  returnToGamemodeDesktop = pkgs.makeDesktopItem {
    name = "return-to-gamemode";
    desktopName = "Return to Gaming Mode";
    comment = "Switch from DankMaterialShell to Steam Gamescope session";
    exec = "${deckSessionSwitch}/bin/deck-session-switch gamescope";
    icon = "steam";
    terminal = false;
    type = "Application";
    categories = ["Game" "System"];
  };
in {
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
    extraPackages = with pkgs; [
      psmisc
      pulseaudio
    ];
  };

  programs.gamemode.enable = true;

  environment.systemPackages = [
    deckSessionSwitch
    steamosSessionSelect
    returnToGamemodeDesktop
    pkgs.psmisc
    pkgs.pulseaudio
  ];

  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${user.home}/.steam/root/compatibilitytools.d";
  };
}
