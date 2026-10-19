# freebuff-headless — headless runner/daemon for the Freebuff (Codebuff) TUI.
#
# Moved out of hosts/frieren/tools.nix (2026-10-19): same reason as
# modules/scripts/wikisearch.nix — the script is a program, not host wiring.
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "freebuff-headless";
  runtimeInputs = with pkgs; [
    tmux
    git
    coreutils
    gnugrep
    gnused
    gawk
    findutils
    procps
  ];
  text = ''
    # freebuff-headless: Headless runner and daemon for Freebuff / Codebuff TUI
    set -euo pipefail

    FREEBUFF_BIN="''${FREEBUFF_BIN:-freebuff}"
    if ! command -v "$FREEBUFF_BIN" >/dev/null 2>&1; then
      if [[ -x "/etc/profiles/per-user/devji/bin/freebuff" ]]; then
        FREEBUFF_BIN="/etc/profiles/per-user/devji/bin/freebuff"
      elif [[ -x "/run/current-system/sw/bin/freebuff" ]]; then
        FREEBUFF_BIN="/run/current-system/sw/bin/freebuff"
      else
        echo "Error: freebuff binary not found in PATH" >&2
        exit 1
      fi
    fi

    show_help() {
      cat <<'HELP'
    freebuff-headless - Headless execution runner for Freebuff (Codebuff)

    Usage:
      freebuff-headless [options] "<prompt>"
      echo "<prompt>" | freebuff-headless [options]

    Options:
      -C, --cwd <dir>       Project root directory (default: current directory or ~)
      -s, --session <name>  Custom tmux session name (default: fb-<timestamp>-<rand>)
      -d, --detach          Dispatch prompt into background tmux session and exit
      -t, --timeout <secs>  Wait timeout in seconds (default: 300)
      -c, --continue [id]   Resume previous conversation ID
      --raw                 Output raw captured scrollback without stripping TUI chrome
      --status              List active freebuff tmux sessions
      --logs <session>      Print current scrollback capture of a session
      --attach <session>    Interactively attach to a session
      --kill <session>      Terminate a session
      -h, --help            Show this help message

    Examples:
      freebuff-headless "Explain the project layout"
      freebuff-headless -C /Volumes/data/projects/nixconfig "Check git status and commit message"
      freebuff-headless -d "Refactor tools.nix"
      freebuff-headless --status
      freebuff-headless --logs fb-1718000000-1234
    HELP
    }

    list_sessions() {
      echo "=== Active Freebuff Sessions ==="
      local found=0
      while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        echo "  $line"
        found=1
      done < <(tmux list-sessions -F "#{session_name}: created #{session_created_string} (#{session_windows} win)" 2>/dev/null | grep -E '^fb-|^freebuff-' || true)
      if [[ "$found" -eq 0 ]]; then
        echo "  (No active freebuff sessions)"
      fi
    }

    show_logs() {
      local sess="$1"
      if ! tmux has-session -t "$sess" 2>/dev/null; then
        echo "Error: tmux session '$sess' not found" >&2
        exit 1
      fi
      tmux capture-pane -p -S -3000 -t "$sess"
    }

    attach_session() {
      local sess="$1"
      if ! tmux has-session -t "$sess" 2>/dev/null; then
        echo "Error: tmux session '$sess' not found" >&2
        exit 1
      fi
      exec tmux attach-session -t "$sess"
    }

    kill_session() {
      local sess="$1"
      if tmux has-session -t "$sess" 2>/dev/null; then
        tmux kill-session -t "$sess"
        echo "Killed session: $sess"
      else
        echo "Session '$sess' does not exist"
      fi
    }

    filter_output() {
      awk '
        /^[[:space:]]*[█▀▄]/ { next }
        /^[[:space:]]*[┌└├│][─]/ { next }
        /^[[:space:]]*[╭╰][─]/ { next }
        /Freebucks remaining/ { next }
        /day streak/ { next }
        /Refer friends/ { next }
        /Copy invite link/ { next }
        /^[[:space:]]*│/ { next }
        /✕ End session/ { next }
        /▍Enter a coding task/ { next }
        /GLM [0-9.]+/ { next }
        /← for history/ { next }
        { print }
      '
    }

    TARGET_DIR="''${PWD}"
    SESSION=""
    DETACH=0
    TIMEOUT=300
    CONTINUE_ARG=""
    RAW=0
    PROMPT=""

    while [[ $# -gt 0 ]]; do
      case "$1" in
        -h|--help)
          show_help
          exit 0
          ;;
        --status)
          list_sessions
          exit 0
          ;;
        --logs)
          if [[ $# -lt 2 ]]; then
            echo "Error: --logs requires session name" >&2
            exit 1
          fi
          show_logs "$2"
          exit 0
          ;;
        --attach)
          if [[ $# -lt 2 ]]; then
            echo "Error: --attach requires session name" >&2
            exit 1
          fi
          attach_session "$2"
          exit 0
          ;;
        --kill)
          if [[ $# -lt 2 ]]; then
            echo "Error: --kill requires session name" >&2
            exit 1
          fi
          kill_session "$2"
          exit 0
          ;;
        -C|--cwd)
          TARGET_DIR="$2"
          shift 2
          ;;
        -s|--session)
          SESSION="$2"
          shift 2
          ;;
        -d|--detach)
          DETACH=1
          shift
          ;;
        -t|--timeout)
          TIMEOUT="$2"
          shift 2
          ;;
        -c|--continue)
          if [[ $# -ge 2 && "$2" != -* ]]; then
            CONTINUE_ARG="--continue $2"
            shift 2
          else
            CONTINUE_ARG="--continue"
            shift 1
          fi
          ;;
        --raw)
          RAW=1
          shift
          ;;
        --)
          shift
          PROMPT="$*"
          break
          ;;
        -*)
          echo "Error: unknown option '$1'" >&2
          show_help
          exit 1
          ;;
        *)
          if [[ -z "$PROMPT" ]]; then
            PROMPT="$1"
          else
            PROMPT="$PROMPT $1"
          fi
          shift
          ;;
      esac
    done

    if [[ -z "$PROMPT" ]]; then
      if ! [[ -t 0 ]]; then
        PROMPT="$(cat)"
      fi
    fi

    if [[ -z "$PROMPT" ]]; then
      echo "Error: no prompt provided" >&2
      show_help
      exit 1
    fi

    TARGET_DIR="$(mkdir -p "$TARGET_DIR" && cd "$TARGET_DIR" && pwd -P)"

    if ! git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git -C "$TARGET_DIR" init -q
    fi

    if [[ -z "$SESSION" ]]; then
      SESSION="fb-$(date +%s)-$RANDOM"
    fi

    tmux kill-session -t "$SESSION" 2>/dev/null || true

    CMD=("$FREEBUFF_BIN" "--trust-agents" "--cwd" "$TARGET_DIR")
    if [[ -n "$CONTINUE_ARG" ]]; then
      # shellcheck disable=SC2206
      CMD+=($CONTINUE_ARG)
    fi

    tmux new-session -d -s "$SESSION" -c "$TARGET_DIR" "''${CMD[@]}"

    READY=0
    for _ in {1..30}; do
      if ! tmux has-session -t "$SESSION" 2>/dev/null; then
        echo "Error: freebuff session terminated unexpectedly" >&2
        exit 1
      fi
      PANE="$(tmux capture-pane -p -t "$SESSION" 2>/dev/null || true)"
      if echo "$PANE" | grep -q "Enter a coding task\|Session active\|Freebucks remaining"; then
        READY=1
        break
      fi
      sleep 0.3
    done

    if [[ "$READY" -eq 0 ]]; then
      echo "Warning: freebuff did not display prompt marker within 9s; attempting prompt dispatch anyway..." >&2
    fi

    tmux send-keys -l -t "$SESSION" "$PROMPT"
    sleep 0.2
    tmux send-keys -t "$SESSION" Enter

    if [[ "$DETACH" -eq 1 ]]; then
      echo "Started headless Freebuff session: $SESSION"
      echo "Directory: $TARGET_DIR"
      echo "Logs:      freebuff-headless --logs $SESSION"
      echo "Attach:    freebuff-headless --attach $SESSION"
      echo "Kill:      freebuff-headless --kill $SESSION"
      exit 0
    fi

    sleep 2
    START_TIME="$(date +%s)"

    while true; do
      NOW="$(date +%s)"
      ELAPSED=$((NOW - START_TIME))
      if [[ "$ELAPSED" -ge "$TIMEOUT" ]]; then
        echo "Warning: execution timed out after ''${TIMEOUT}s" >&2
        break
      fi

      if ! tmux has-session -t "$SESSION" 2>/dev/null; then
        break
      fi

      PANE="$(tmux capture-pane -p -t "$SESSION" 2>/dev/null || true)"
      if [[ -z "$PANE" ]]; then
        break
      fi

      if ! echo "$PANE" | grep -q "■ Esc"; then
        if echo "$PANE" | grep -q "Enter a coding task\|✕ End session"; then
          sleep 1.5
          PANE_VERIFY="$(tmux capture-pane -p -t "$SESSION" 2>/dev/null || true)"
          if ! echo "$PANE_VERIFY" | grep -q "■ Esc"; then
            break
          fi
        fi
      fi

      sleep 1
    done

    OUTPUT="$(tmux capture-pane -p -S -4000 -t "$SESSION" 2>/dev/null || true)"

    tmux send-keys -t "$SESSION" "/exit" Enter 2>/dev/null || true
    sleep 0.5
    tmux kill-session -t "$SESSION" 2>/dev/null || true

    if [[ "$RAW" -eq 1 ]]; then
      echo "$OUTPUT"
    else
      echo "$OUTPUT" | filter_output
    fi
  '';
}
