# `programs.mainframe-remotes`: launchers that attach to the deck on delphi.
{
  pkgs,
  lib,
  config,
  ...
}: let
  # ── 1. AGY Mainframe Client ──────────────────────────────────────────────
  agy-terminal = pkgs.writeShellApplication {
    name = "agy-terminal";
    runtimeInputs = with pkgs; [
      openssh
      coreutils
    ];
    text = ''
      set -euo pipefail
      MAINFRAME_HOST="''${AGY_HOST:-frieren.lan}"
      SESSION="''${AGY_SESSION:-agy}"
      CWD="''${AGY_CWD:-/Volumes/data/projects}"
      TITLE="Antigravity (frieren.lan)"

      REMOTE="tmux new-session -A -s '$SESSION' bash -lc 'cd \"$CWD\" && agy --dangerously-skip-permissions'"

      if command -v kitty >/dev/null 2>&1; then
        exec kitty --title "$TITLE" -e ssh -t "$MAINFRAME_HOST" "$REMOTE"
      elif command -v alacritty >/dev/null 2>&1; then
        exec alacritty -T "$TITLE" -e ssh -t "$MAINFRAME_HOST" "$REMOTE"
      else
        exec "''${TERMINAL:-xterm}" -e ssh -t "$MAINFRAME_HOST" "$REMOTE"
      fi
    '';
  };

  agy-remote = pkgs.writeShellApplication {
    name = "agy-remote";
    runtimeInputs = with pkgs; [
      openssh
      coreutils
    ];
    text = ''
      # agy-remote: Plan 9-style thin client for Antigravity on frieren mainframe
      set -euo pipefail

      MAINFRAME_HOST="''${AGY_HOST:-frieren.lan}"
      SESSION="''${AGY_SESSION:-agy}"

      show_help() {
        cat <<'HELP'
      agy-remote - Mainframe client for Antigravity (agy) on frieren.lan

      Offloads Antigravity agent sessions with --dangerously-skip-permissions
      to the frieren mainframe inside a persistent tmux session.

      Usage:
        agy-remote [options] [query/args...]

      Subcommands & Options:
        -i, --interactive [dir] Launch or attach to interactive tmux session
        -a, --attach [name]     Attach to existing remote agy tmux session
        --status                Show running agy tmux sessions on frieren
        --kill [name]           Kill remote agy tmux session
        -C, --cwd <dir>         Set remote working directory
        -t, --terminal          Open in a new desktop terminal window
        -h, --help              Show this help message

      Environment:
        AGY_HOST                Remote mainframe host (default: frieren.lan)
        AGY_SESSION             Custom tmux session name (default: agy)
      HELP
      }

      # If running directly on frieren, run agy locally
      if [[ "$(hostname 2>/dev/null || true)" == "frieren" ]]; then
        exec agy --dangerously-skip-permissions "$@"
      fi

      case "''${1:-}" in
        -h|--help)
          show_help
          exit 0
          ;;
        -t|--terminal)
          shift
          exec agy-terminal "$@"
          ;;
        --status)
          exec ssh "$MAINFRAME_HOST" "tmux list-sessions 2>/dev/null | grep -E '^agy' || echo 'No active agy sessions on frieren.'"
          ;;
        --kill)
          shift
          TARGET="''${1:-$SESSION}"
          exec ssh "$MAINFRAME_HOST" "tmux kill-session -t $(printf '%q' "$TARGET") 2>/dev/null && echo 'Killed session $TARGET' || echo 'Session $TARGET not found'"
          ;;
        -a|--attach)
          shift
          TARGET="''${1:-$SESSION}"
          exec ssh -t "$MAINFRAME_HOST" "tmux attach-session -t $(printf '%q' "$TARGET")"
          ;;
      esac

      # Resolve working directory: prefer current dir if on /Volumes/data NAS mount
      REMOTE_DIR="''${AGY_CWD:-/Volumes/data/projects}"
      if [[ "$PWD" == /Volumes/data* ]]; then
        REMOTE_DIR="$PWD"
      fi

      ARGS=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -C|--cwd)
            shift
            REMOTE_DIR="$1"
            ;;
          --cwd=*)
            REMOTE_DIR="''${1#*=}"
            ;;
          *)
            ARGS+=("$1")
            ;;
        esac
        shift
      done

      REMOTE_CMD="cd $(printf '%q' "$REMOTE_DIR") && agy --dangerously-skip-permissions"
      if [[ ''${#ARGS[@]} -gt 0 ]]; then
        for a in "''${ARGS[@]}"; do
          REMOTE_CMD+=" $(printf '%q' "$a")"
        done
      fi

      if [[ -t 0 ]]; then
        exec ssh -t "$MAINFRAME_HOST" "tmux new-session -A -s '$SESSION' bash -lc $(printf '%q' "$REMOTE_CMD")"
      else
        exec ssh "$MAINFRAME_HOST" "bash -lc $(printf '%q' "$REMOTE_CMD")"
      fi
    '';
  };

  # ── 2. Hermes Mainframe Client ───────────────────────────────────────────
  hermes-terminal = pkgs.writeShellApplication {
    name = "hermes-terminal";
    runtimeInputs = with pkgs; [
      openssh
      coreutils
    ];
    text = ''
      set -euo pipefail
      MAINFRAME_HOST="''${HERMES_HOST:-frieren.lan}"
      SESSION="''${HERMES_SESSION:-hermes}"
      CWD="''${HERMES_CWD:-/Volumes/data/projects}"
      TITLE="Hermes Agent (frieren.lan)"

      REMOTE="tmux new-session -A -s '$SESSION' bash -lc 'cd \"$CWD\" && hermes chat'"

      if command -v kitty >/dev/null 2>&1; then
        exec kitty --title "$TITLE" -e ssh -t "$MAINFRAME_HOST" "$REMOTE"
      elif command -v alacritty >/dev/null 2>&1; then
        exec alacritty -T "$TITLE" -e ssh -t "$MAINFRAME_HOST" "$REMOTE"
      else
        exec "''${TERMINAL:-xterm}" -e ssh -t "$MAINFRAME_HOST" "$REMOTE"
      fi
    '';
  };

  hermes-remote = pkgs.writeShellApplication {
    name = "hermes-remote";
    runtimeInputs = with pkgs; [
      openssh
      coreutils
    ];
    text = ''
      # hermes-remote: Plan 9-style thin client for Hermes on frieren mainframe
      set -euo pipefail

      MAINFRAME_HOST="''${HERMES_HOST:-frieren.lan}"
      SESSION="''${HERMES_SESSION:-hermes}"

      show_help() {
        cat <<'HELP'
      hermes-remote - Mainframe client for Hermes Agent on frieren.lan

      Offloads Hermes sessions to the frieren mainframe inside a persistent
      tmux session, preserving persona, memories, and host context.

      Usage:
        hermes-remote [options] [args...]

      Subcommands & Options:
        -i, --interactive [dir] Launch or attach to interactive tmux session
        -a, --attach [name]     Attach to existing remote hermes tmux session
        --status                Show running hermes tmux sessions on frieren
        --kill [name]           Kill remote hermes tmux session
        -C, --cwd <dir>         Set remote working directory
        -t, --terminal          Open in a new desktop terminal window
        -h, --help              Show this help message

      Environment:
        HERMES_HOST             Remote mainframe host (default: frieren.lan)
        HERMES_SESSION          Custom tmux session name (default: hermes)
      HELP
      }

      # If running directly on frieren, run hermes locally
      if [[ "$(hostname 2>/dev/null || true)" == "frieren" ]]; then
        exec hermes "$@"
      fi

      case "''${1:-}" in
        -h|--help)
          show_help
          exit 0
          ;;
        -t|--terminal)
          shift
          exec hermes-terminal "$@"
          ;;
        --status)
          exec ssh "$MAINFRAME_HOST" "tmux list-sessions 2>/dev/null | grep -E '^hermes' || echo 'No active hermes sessions on frieren.'"
          ;;
        --kill)
          shift
          TARGET="''${1:-$SESSION}"
          exec ssh "$MAINFRAME_HOST" "tmux kill-session -t $(printf '%q' "$TARGET") 2>/dev/null && echo 'Killed session $TARGET' || echo 'Session $TARGET not found'"
          ;;
        -a|--attach)
          shift
          TARGET="''${1:-$SESSION}"
          exec ssh -t "$MAINFRAME_HOST" "tmux attach-session -t $(printf '%q' "$TARGET")"
          ;;
      esac

      # Resolve working directory: prefer current dir if on /Volumes/data NAS mount
      REMOTE_DIR="''${HERMES_CWD:-/Volumes/data/projects}"
      if [[ "$PWD" == /Volumes/data* ]]; then
        REMOTE_DIR="$PWD"
      fi

      ARGS=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -C|--cwd)
            shift
            REMOTE_DIR="$1"
            ;;
          --cwd=*)
            REMOTE_DIR="''${1#*=}"
            ;;
          *)
            ARGS+=("$1")
            ;;
        esac
        shift
      done

      # Default to 'hermes chat' if no arguments passed
      if [[ ''${#ARGS[@]} -eq 0 ]]; then
        ARGS=("chat")
      fi

      REMOTE_CMD="cd $(printf '%q' "$REMOTE_DIR") && hermes"
      for a in "''${ARGS[@]}"; do
        REMOTE_CMD+=" $(printf '%q' "$a")"
      done

      if [[ -t 0 ]]; then
        exec ssh -t "$MAINFRAME_HOST" "tmux new-session -A -s '$SESSION' bash -lc $(printf '%q' "$REMOTE_CMD")"
      else
        exec ssh "$MAINFRAME_HOST" "bash -lc $(printf '%q' "$REMOTE_CMD")"
      fi
    '';
  };
in {
  options.programs.mainframe-remotes.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install thin clients for agy and hermes targeting the frieren mainframe.";
  };

  config = lib.mkIf (config.programs.mainframe-remotes.enable && (config.profiles.ai.enable or true)) {
    home.packages = [
      agy-remote
      agy-terminal
      hermes-remote
      hermes-terminal
    ];

    # `xdg.desktopEntries` is a Linux-only module (home-manager asserts on its
    # platform), and this module is shared with nix-darwin: on cassini the
    # assertion failed the whole home profile. The remote launchers still
    # install on darwin; only the menu entries are dropped.
    xdg = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      desktopEntries.agy-remote = {
        name = "Antigravity Remote";
        genericName = "Mainframe Coding Agent";
        comment = "Connect to Antigravity on frieren.lan";
        exec = "agy-terminal";
        icon = "utilities-terminal";
        terminal = false;
        categories = [
          "Development"
          "Utility"
        ];
      };

      desktopEntries.hermes-remote = {
        name = "Hermes Remote";
        genericName = "Mainframe Hermes Agent";
        comment = "Connect to Hermes Agent on frieren.lan";
        exec = "hermes-terminal";
        icon = "utilities-terminal";
        terminal = false;
        categories = [
          "Development"
          "Utility"
        ];
      };
    };
  };
}
