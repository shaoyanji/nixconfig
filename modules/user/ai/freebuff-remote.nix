{
  pkgs,
  lib,
  config,
  ...
}: let
  # Layer 1 helper (fleet client integration): desktop launcher that opens
  # the persistent Freebuff tmux session on the frieren mainframe, using the
  # best available terminal emulator (kitty on fleet desktops, alacritty on
  # netbook, $TERMINAL/xterm fallback).
  freebuff-terminal = pkgs.writeShellApplication {
    name = "freebuff-terminal";
    runtimeInputs = with pkgs; [
      openssh
      coreutils
    ];
    text = ''
      # freebuff-terminal: attach to the persistent Freebuff tmux session on
      # the frieren mainframe inside the best available terminal emulator.
      set -euo pipefail

      FREEBUFF_HOST="''${FREEBUFF_HOST:-frieren.lan}"
      SESSION="''${FREEBUFF_SESSION:-freebuff}"
      CWD="''${FREEBUFF_CWD:-/Volumes/data/projects}"
      TITLE="Freebuff (frieren.lan)"

      # Attach if the session exists, otherwise create it running the Freebuff
      # TUI. bash -lc so the non-login SSH shell still picks up /etc/profile
      # PATH and finds the per-user `freebuff` binary.
      REMOTE="tmux new-session -A -s '$SESSION' bash -lc 'freebuff --trust-agents --cwd $CWD'"

      if command -v kitty >/dev/null 2>&1; then
        exec kitty --title "$TITLE" -e ssh -t "$FREEBUFF_HOST" "$REMOTE"
      elif command -v alacritty >/dev/null 2>&1; then
        exec alacritty -T "$TITLE" -e ssh -t "$FREEBUFF_HOST" "$REMOTE"
      else
        # shellcheck disable=SC2230
        exec "''${TERMINAL:-xterm}" -e ssh -t "$FREEBUFF_HOST" "$REMOTE"
      fi
    '';
  };

  freebuff-remote = pkgs.writeShellApplication {
    name = "freebuff-remote";
    runtimeInputs = with pkgs; [
      openssh
      coreutils
    ];
    text = ''
      # freebuff-remote: Plan 9-style thin client for offloading Freebuff tasks to frieren mainframe
      set -euo pipefail

      FREEBUFF_HOST="''${FREEBUFF_HOST:-frieren.lan}"
      export SSH_AUTH_SOCK="''${SSH_AUTH_SOCK:-/run/user/1000/gcr/ssh}"

      show_help() {
        cat <<'HELP'
      freebuff-remote - Plan 9-style mainframe client for Freebuff

      Delegates AI coding tasks from this lightweight client node to the
      high-compute frieren.lan server without persistent local RAM or CPU overhead.

      Usage:
        freebuff-remote [options] "<prompt>"
        echo "<prompt>" | freebuff-remote [options]

      Subcommands & Actions:
        -i, --interactive [dir] Interactive full-screen Freebuff TUI session on frieren
        -a, --attach <session>  Attach interactively to an existing remote tmux session
        --status                List active Freebuff sessions running on frieren
        --logs <session>        Fetch scrollback capture from a remote session
        --kill <session>        Terminate a remote Freebuff session

      Options:
        -C, --cwd <dir>         Remote directory (auto-detects shared /Volumes/data paths)
        -s, --session <name>    Custom remote session name
        -d, --detach            Launch in background on frieren and exit immediately
        -t, --timeout <secs>    Wait timeout in seconds (default: 300)
        -c, --continue [id]     Resume previous conversation ID
        --raw                   Output raw captured scrollback without stripping TUI chrome
        -h, --help              Show this help message

      Environment:
        FREEBUFF_HOST           Remote host (default: frieren.lan)

      Examples:
        freebuff-remote "Review unstaged git diff"
        freebuff-remote -C /Volumes/data/projects/nixconfig "Inspect flake.nix"
        freebuff-remote -i /Volumes/data/projects/nixconfig
        freebuff-remote -d "Audit security ports"
        freebuff-remote --status
        freebuff-remote --attach fb-1718000000-1234
      HELP
      }

      # If running directly on frieren, invoke freebuff-headless locally
      if [[ "$(hostname 2>/dev/null || true)" == "frieren" ]]; then
        exec freebuff-headless "$@"
      fi

      if [[ $# -eq 0 && -t 0 ]]; then
        show_help
        exit 0
      fi

      case "''${1:-}" in
        -h|--help)
          show_help
          exit 0
          ;;
        -i|--interactive)
          shift
          REMOTE_DIR="''${1:-}"
          if [[ -z "$REMOTE_DIR" && "$PWD" == /Volumes/data* ]]; then
            REMOTE_DIR="$PWD"
          fi
          if [[ -n "$REMOTE_DIR" ]]; then
            exec ssh -t "$FREEBUFF_HOST" "freebuff --trust-agents --cwd $(printf '%q' "$REMOTE_DIR")"
          else
            exec ssh -t "$FREEBUFF_HOST" "freebuff --trust-agents"
          fi
          ;;
        -a|--attach)
          shift
          if [[ $# -lt 1 ]]; then
            echo "Error: --attach requires session name" >&2
            exit 1
          fi
          exec ssh -t "$FREEBUFF_HOST" "tmux attach-session -t $(printf '%q' "$1")"
          ;;
        --status)
          exec ssh "$FREEBUFF_HOST" "freebuff-headless --status"
          ;;
        --logs)
          shift
          if [[ $# -lt 1 ]]; then
            echo "Error: --logs requires session name" >&2
            exit 1
          fi
          exec ssh "$FREEBUFF_HOST" "freebuff-headless --logs $(printf '%q' "$1")"
          ;;
        --kill)
          shift
          if [[ $# -lt 1 ]]; then
            echo "Error: --kill requires session name" >&2
            exit 1
          fi
          exec ssh "$FREEBUFF_HOST" "freebuff-headless --kill $(printf '%q' "$1")"
          ;;
      esac

      HAS_CWD=0
      for arg in "$@"; do
        if [[ "$arg" == "-C" || "$arg" == "--cwd" || "$arg" == --cwd=* ]]; then
          HAS_CWD=1
          break
        fi
      done

      FORWARD_ARGS=()
      if [[ "$HAS_CWD" -eq 0 && "$PWD" == /Volumes/data* ]]; then
        FORWARD_ARGS+=("-C" "$PWD")
      fi

      for arg in "$@"; do
        FORWARD_ARGS+=("$(printf '%q' "$arg")")
      done

      if ! [[ -t 0 ]]; then
        exec ssh "$FREEBUFF_HOST" "freebuff-headless ''${FORWARD_ARGS[*]}"
      else
        exec ssh "$FREEBUFF_HOST" "freebuff-headless ''${FORWARD_ARGS[*]}"
      fi
    '';
  };
in {
  options.programs.freebuff-remote.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the Plan 9-style thin client for Freebuff on frieren.";
  };

  config = lib.mkIf (config.programs.freebuff-remote.enable && (config.profiles.ai.enable or true)) {
    home.packages = [
      freebuff-remote
      freebuff-terminal
    ];

    # Layer 1 — XDG desktop entry. DMS Spotlight (Mod+Space / Mod+N), Fuzzel
    # (Mod+A) and Kando (Ctrl+Space) all read XDG data dirs, so typing
    # `freebuff` surfaces the mainframe terminal on every fleet desktop.
    xdg.desktopEntries.freebuff = {
      name = "Freebuff";
      genericName = "AI Coding Mainframe";
      comment = "Connect to Freebuff AI coding assistant on frieren.lan";
      exec = "freebuff-terminal";
      icon = "utilities-terminal";
      terminal = false;
      categories = [
        "Development"
        "System"
        "Utility"
      ];
      settings = {
        Keywords = "ai;freebuff;codebuff;frieren;llm;coding;";
      };
    };
  };
}
