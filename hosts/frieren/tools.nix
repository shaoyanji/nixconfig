{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption;
  cfg = config.services.nasTools;

  wikisearch = pkgs.writeShellApplication {
    name = "wikisearch";
    runtimeInputs = with pkgs; [
      kiwix-tools
      curl
      coreutils
      gnugrep
      gnused
      findutils
      gawk
      systemd
    ];
    text = ''
      # wikisearch: Universal search client for any Kiwix-served wiki or offline ZIM archive
      set -euo pipefail

      KIWIX_DIR="''${KIWIX_DIR:-/var/lib/kiwix}"
      KIWIX_LIBRARY="''${KIWIX_LIBRARY:-$KIWIX_DIR/library.xml}"
      KIWIX_PORT="''${KIWIX_PORT:-8088}"
      KIWIX_HOST="''${KIWIX_HOST:-http://127.0.0.1:$KIWIX_PORT}"

      show_help() {
        cat <<'HELP'
      wikisearch - Universal Offline Wiki Search (BM25 & Kiwix)

      Usage:
        wikisearch [options] "<query>"

      Options:
        -w, --wiki <name>     Select target wiki by name, title, or filename (e.g. -w top, -w arch, -w all)
        -l, --list            List all available wiki archives in library
        -s, --suggest <term>  Auto-complete / title prefix suggestions
        -u, --url             Print full Kiwix HTTP URLs instead of plain titles
        --status              Show Kiwix server and library status
        -h, --help            Show this help message

      Environment Variables:
        KIWIX_DIR             Base directory for ZIM archives (default: /var/lib/kiwix)
        KIWIX_LIBRARY         Path to Kiwix library.xml (default: $KIWIX_DIR/library.xml)
        KIWIX_HOST            Kiwix HTTP host/port (default: http://127.0.0.1:8088)

      Examples:
        wikisearch "quantum computing"
        wikisearch -w top "Alan Turing"
        wikisearch -s "Antigrav"
        wikisearch -l
      HELP
      }

      list_wikis() {
        if [[ -f "$KIWIX_LIBRARY" ]] && command -v kiwix-manage >/dev/null 2>&1; then
          kiwix-manage "$KIWIX_LIBRARY" show | awk '
            /^id:/ { id=$2 }
            /^title:/ { sub(/^title:[[:space:]]*/, ""); title=$0 }
            /^path:/ { sub(/^path:[[:space:]]*/, ""); path=$0 }
            /^articleCount:/ {
              count=$2
              split(path, p, "/")
              file=p[length(p)]
              printf "  %-25s | %10s articles | %s (%s)\n", title, count, file, id
            }
          '
        else
          echo "Scanning $KIWIX_DIR for ZIM files:"
          for f in "$KIWIX_DIR"/*.zim; do
            [[ -e "$f" ]] || continue
            [[ "$f" == *.aria2 ]] && continue
            basename "$f"
          done
        fi
      }

      show_status() {
        echo "=== Kiwix Server Status ==="
        # kiwix-serve is a SYSTEM service (services.kiwix-serve, kiwix.nix)
        if systemctl is-active kiwix-serve.service --quiet 2>/dev/null; then
          echo "HTTP Server: Active on $KIWIX_HOST"
        else
          echo "HTTP Server: Inactive"
        fi

        echo ""
        echo "=== Available Archives ==="
        list_wikis
      }

      find_zim() {
        local target="$1"
        local matched=""

        # 1. Direct path check
        if [[ -f "$target" ]]; then
          echo "$target"
          return 0
        fi

        # 2. Declarative library (hosts/frieren/kiwix.nix): books are
        #    /nix/store paths (world-readable) that kiwix-search can open
        #    directly. Match -w targets against them first; with no target,
        #    default to the first declared book (Wikipedia full archive).
        if [[ -f "$KIWIX_LIBRARY" ]]; then
          local lib_paths=""
          lib_paths="$(grep -o 'path="[^"]*"' "$KIWIX_LIBRARY" 2>/dev/null | sed 's/^path="//; s/"$//' || true)"
          if [[ -n "$lib_paths" ]]; then
            if [[ -n "$target" ]]; then
              matched="$(printf '%s\n' "$lib_paths" | grep -iF -- "$target" | head -n 1 || true)"
            else
              matched="$(printf '%s\n' "$lib_paths" | head -n 1 || true)"
            fi
            if [[ -n "$matched" && ! -f "$matched" ]]; then
              matched=""
            fi
          fi
        fi

        # 3. Check in KIWIX_DIR by pattern (local-only archives, e.g. -w top)
        if [[ -z "$matched" && -n "$target" ]]; then
          for f in "$KIWIX_DIR"/*"$target"*.zim; do
            if [[ -f "$f" && ! -f "$f.aria2" ]]; then
              matched="$f"
              break
            fi
          done
        fi

        # 4. If still no match and no target, select best available (preferring *all* over *mini* / *top*)
        if [[ -z "$matched" && -z "$target" ]]; then
          for f in "$KIWIX_DIR"/*all*.zim; do
            if [[ -f "$f" && ! -f "$f.aria2" ]]; then
              matched="$f"
              break
            fi
          done
          if [[ -z "$matched" ]]; then
            for f in "$KIWIX_DIR"/*.zim; do
              if [[ -f "$f" && ! -f "$f.aria2" ]]; then
                matched="$f"
                break
              fi
            done
          fi
        fi

        if [[ -n "$matched" ]]; then
          echo "$matched"
          return 0
        fi

        return 1
      }

      MODE="search"
      WIKI_TARGET=""
      PRINT_URLS=0
      QUERY=""

      while [[ $# -gt 0 ]]; do
        case "$1" in
          -h|--help)
            show_help
            exit 0
            ;;
          --status)
            show_status
            exit 0
            ;;
          -l|--list)
            list_wikis
            exit 0
            ;;
          -s|--suggest)
            MODE="suggest"
            QUERY="''${2:-}"
            shift 2 2>/dev/null || shift 1
            ;;
          -w|--wiki)
            WIKI_TARGET="''${2:-}"
            shift 2 2>/dev/null || shift 1
            ;;
          -u|--url)
            PRINT_URLS=1
            shift
            ;;
          --)
            shift
            QUERY="$*"
            break
            ;;
          -*)
            echo "Error: unknown option '$1'" >&2
            show_help
            exit 1
            ;;
          *)
            QUERY="$*"
            break
            ;;
        esac
      done

      if [[ -z "$QUERY" ]]; then
        show_help
        exit 1
      fi

      if ! ZIM_FILE="$(find_zim "$WIKI_TARGET")"; then
        echo "Error: could not find matching ZIM archive for '$WIKI_TARGET' in $KIWIX_DIR" >&2
        exit 1
      fi

      if [[ "$MODE" == "suggest" ]]; then
        kiwix-search -s "$ZIM_FILE" "$QUERY"
        exit 0
      fi

      if [[ "$PRINT_URLS" -eq 1 ]]; then
        ENCODED="''${QUERY// /%20}"
        RESPONSE=$(curl -sf "$KIWIX_HOST/search?pattern=$ENCODED" 2>/dev/null || true)
        if [[ -n "$RESPONSE" ]]; then
          echo "$RESPONSE" | grep -oP '(?<=href=")/content/[^"]+' | while read -r path; do
            echo "$KIWIX_HOST$path"
          done
          exit 0
        fi
      fi

      kiwix-search "$ZIM_FILE" "$QUERY"
    '';
  };

  freebuff-headless = pkgs.writeShellApplication {
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
  };

  heavyTools = with pkgs; [
    go
    uv
    gh
    neo4j
    typst
    (pkgs.python3.withPackages (
      ps:
        with ps; [
          neo4j
          pytz
          firecrawl-py
          pydantic
        ]
    ))
  ];

  lightTools = with pkgs; [
    wikisearch
    freebuff-headless
    # frieren is the fleet's Freebuff mainframe: the TUI runs here and
    # clients reach it via freebuff-remote/freebuff-terminal (SSH).
    pkgs.llm-agents.freebuff
    # hermes-agent — Fryuni fork of the 2026-09 teardown; lives on the
    # mainframe only (see fleet closure policy in ~/HANDOFF.md).
    pkgs.llm-agents.hermes-agent
    skills
    cowsay
    figlet
    graphviz
    vim
    wget
    git
    btop
    btrfs-progs
    f2fs-tools
    yq-go
    ddgr
    bat
    fd
    sqlite
    fzf
    delta
    httpie
    ncdu
    tree
    unzip
    xxd
    lsof
    pv
    miller
    glow
    sd
    hyperfine
    tldr
    watch
    pup
    htmlq
    gnumake
    shellcheck
    entr
    file
    rsync
    jq
    himalaya
  ];
in {
  options.services.nasTools = {
    enableHeavy = mkEnableOption "Heavy dev tools (go, uv, gh, neo4j, python research env)";
  };

  config = {
    environment.systemPackages =
      lightTools ++ [pkgs.plocate] ++ lib.optionals cfg.enableHeavy heavyTools;

    # --- Fast Filesystem Indexing (plocate) ---
    services.locate = {
      enable = true;
      package = pkgs.plocate;
      interval = "hourly";
      # services.locate.localuser was removed upstream (findutils locate dropped);
      # the plocate updatedb service runs as root regardless.
      pruneFS = [
        "tmpfs"
        "proc"
        "sysfs"
        "devpts"
      ];
      pruneNames = [
        ".git"
        ".hg"
        ".svn"
        ".snapshots"
      ];
      prunePaths = [
        "/tmp"
        "/var/tmp"
        "/nix/store"
        "/.snapshots"
      ];
    };
  };
}
