{
  pkgs,
  lib,
  config,
  ...
}: let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;

  # DeepSeek's square mark, fetched at build into the store — no binary in git.
  # The favicon is an ICO; XDG icon lookup does not index ICO containers, so it
  # is converted once here and the PNG is what gets installed.
  iconIco = pkgs.fetchurl {
    url = "https://www.deepseek.com/favicon.ico";
    hash = "sha256-MKRCDm5Nyxf9feVgxQBDRsK8jNlx0tX17hUyZgPlEyE=";
  };
  iconFile = pkgs.runCommand "deepseek.png" {nativeBuildInputs = [pkgs.imagemagick];} ''
    magick ${iconIco} -resize 256x256 $out
  '';

  # The harness runs on the worker; the browser runs here. `dsh web` binds
  # loopback and prints one tokenised URL, so this launcher forwards a free
  # local port to the worker's port, rewrites that URL onto the local port, and
  # opens it. The token is a process constant (not single-use) and the session
  # cookie it mints is keyed to the Host the browser sends, so the forward
  # works for the UI *and* for the /api WebSocket, and the DeepSeek sign-in
  # redirect comes back through the same tunnel.
  #
  # Public SSH (delphi.bountystash.com), NOT Tailscale SSH: the tailnet path
  # triggers a browser device check that turns an unattended launch into a
  # five-minute hang.
  dshRemote = pkgs.writeShellApplication {
    name = "dsh-remote";
    runtimeInputs = [
      pkgs.openssh
      pkgs.coreutils
      pkgs.iproute2
      pkgs.gawk
      pkgs.gnugrep
      pkgs.curl
      pkgs.xdg-utils
    ];
    text = ''
      set -euo pipefail

      HOST="''${DSH_HOST:-delphi.bountystash.com}"
      SESSION="''${DSH_SESSION:-dsh}"
      PORT_BASE="''${DSH_PORT:-3080}"
      DIR="''${DSH_DIR:-~}"
      PROFILE="''${DSH_PROFILE:-web}"
      ACTION="run"
      SYNC_AUTH="''${DSH_SYNC_AUTH:-auto}"
      OPEN_BROWSER="''${DSH_OPEN_BROWSER:-1}"
      NEW_SESSION=0

      SSH_BATCH=(-o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=20)

      die() {
        printf 'dsh-remote: %s\n' "$*" >&2
        exit 1
      }

      usage() {
        cat <<'EOF'
      dsh-remote — run the DeepSeek Harness on a remote worker, render it in this browser

        dsh-remote                 web UI in this browser, harness in a tmux session
        dsh-remote --profile <p>   boot another dsh profile in tmux and attach to it
                                   (this build ships acp, web, headless, sdk; no tui)
        dsh-remote -C <dir>        start the harness in <dir> (default: the worker's $HOME)
        dsh-remote --new           a fresh session instead of reusing the running one
        dsh-remote --status        is the harness running, and on which port
        dsh-remote --kill          stop the session on the worker
        dsh-remote --sync-auth     re-import this client's DeepSeek credential over ssh
        dsh-remote --no-sync-auth  never import it; sign in through the Web UI instead
        dsh-remote --no-browser    print the URL instead of opening a browser
        dsh-remote --host <h>      another worker (default delphi.bountystash.com)

      The harness listens on loopback on the worker; dsh-remote forwards one local
      port to it, rewrites the one-time URL onto that port, and hands it to the
      browser. Signing in to a DeepSeek account in that browser tab works through the
      same tunnel, and a signed-in client's ~/.dsh credential is imported over ssh so
      the worker usually boots already authenticated.

      Env: DSH_HOST DSH_SESSION DSH_PORT DSH_DIR DSH_PROFILE DSH_SYNC_AUTH DSH_OPEN_BROWSER
      DRY_RUN=1 prints the plan without touching the worker.
      EOF
      }

      while [ $# -gt 0 ]; do
        case "$1" in
          -C | --dir)
            [ $# -ge 2 ] || die "$1 needs a directory"
            DIR="$2"
            shift 2
            ;;
          --host)
            [ $# -ge 2 ] || die "$1 needs a host"
            HOST="$2"
            shift 2
            ;;
          --profile)
            [ $# -ge 2 ] || die "$1 needs a profile name"
            PROFILE="$2"
            shift 2
            ;;
          --new)
            NEW_SESSION=1
            shift
            ;;
          --sync-auth)
            SYNC_AUTH=always
            shift
            ;;
          --no-sync-auth)
            SYNC_AUTH=never
            shift
            ;;
          --no-browser)
            OPEN_BROWSER=0
            shift
            ;;
          --status)
            ACTION="status"
            shift
            ;;
          --kill)
            ACTION="kill"
            shift
            ;;
          -h | --help)
            usage
            exit 0
            ;;
          *)
            printf 'dsh-remote: unknown argument %s (try --help)\n' "$1" >&2
            exit 2
            ;;
        esac
      done

      case "$DIR" in
        *" "* | *"'"* | *'"'* | *'$'* | *'`'* | *\\*)
          die "a directory with spaces or shell metacharacters is not supported: $DIR"
          ;;
      esac

      # A menu entry has no terminal. Re-exec in one so the tmux attach has a tty;
      # the sentinel stops a terminal that does not hand one back from looping.
      if [ "$ACTION" = run ] && [ ! -t 0 ] && [ "''${DSH_IN_TERM:-0}" != 1 ]; then
        export DSH_IN_TERM=1
        for term in "''${TERMINAL:-}" kitty alacritty xterm; do
          [ -n "$term" ] || continue
          command -v "$term" >/dev/null 2>&1 || continue
          case "$(basename "$term")" in
            kitty) exec "$term" --title "DeepSeek Harness ($HOST)" -e "$0" "$@" ;;
            *) exec "$term" -e "$0" "$@" ;;
          esac
        done
      fi

      case "$PROFILE" in
        "" | *" "* | *"'"* | *'"'* | *'$'* | *'`'* | */*) die "unsupported profile name: $PROFILE" ;;
      esac

      # Each non-web profile gets its own session, so a web session and an acp one
      # never collide on the same name and a reuse can't attach to the wrong app.
      if [ "$PROFILE" != web ]; then
        SESSION="$SESSION-$PROFILE"
      fi

      if [ "$NEW_SESSION" = 1 ]; then
        SESSION="$SESSION-$(date +%s)"
      fi

      # Every remote call is a script on stdin (`bash -ls -- args`): the values we
      # pass are space-free and the script itself never needs a second quoting layer.
      remote() {
        ssh "''${SSH_BATCH[@]}" "$HOST" bash -ls -- "$@"
      }

      remote_root() {
        local out
        out=$(remote <<'REMOTE' 2>/dev/null || true
      printf 'DSHROOT:%s\n' "''${DSH_HOME:-$HOME/.dsh}"
      REMOTE
        )
        printf '%s\n' "$out" | sed -n 's/^DSHROOT://p' | tail -1
      }

      require_host() {
        local err
        if ! err=$(ssh "''${SSH_BATCH[@]}" "$HOST" true 2>&1); then
          printf 'dsh-remote: cannot reach %s non-interactively.\n' "$HOST" >&2
          printf '%s\n' "$err" >&2
          printf 'dsh-remote: accept its host key once with: ssh %s true\n' "$HOST" >&2
          exit 1
        fi
      }

      # --- status / kill ----------------------------------------------------------

      if [ "$ACTION" = status ]; then
        require_host
        out=$(remote "$SESSION" <<'REMOTE' 2>/dev/null || true
      root=''${DSH_HOME:-$HOME/.dsh}
      if tmux has-session -t "$1" 2>/dev/null; then
        port=$(sed -n 's|^.*http://127\.0\.0\.1:\([0-9][0-9]*\).*|\1|p' "$root/web-$1.log" 2>/dev/null | tail -1)
        printf 'DSHSTATUS:running %s\n' "''${port:-unknown-port}"
      else
        printf 'DSHSTATUS:stopped\n'
      fi
      REMOTE
        )
        line=$(printf '%s\n' "$out" | sed -n 's/^DSHSTATUS://p' | tail -1)
        case "$line" in
          "running "*)
            p=''${line#running }
            printf 'dsh-remote: session %s is running on %s (harness on 127.0.0.1:%s)\n' "$SESSION" "$HOST" "$p"
            ;;
          stopped)
            printf 'dsh-remote: no harness session %s on %s\n' "$SESSION" "$HOST"
            ;;
          *)
            die "could not read the harness state on $HOST"
            ;;
        esac
        exit 0
      fi

      if [ "$ACTION" = kill ]; then
        require_host
        root=$(remote_root)
        out=$(remote "$SESSION" <<'REMOTE' 2>/dev/null || true
      if tmux kill-session -t "$1" 2>/dev/null; then printf 'DSHKILL:killed\n'; else printf 'DSHKILL:absent\n'; fi
      rm -f "''${DSH_HOME:-$HOME/.dsh}/web-$1.log"
      REMOTE
        )
        case "$(printf '%s\n' "$out" | sed -n 's/^DSHKILL://p' | tail -1)" in
          killed) printf 'dsh-remote: stopped session %s on %s\n' "$SESSION" "$HOST" ;;
          absent) printf 'dsh-remote: session %s was not running on %s\n' "$SESSION" "$HOST" ;;
          *) die "could not confirm the kill on $HOST (harness home: ''${root:-unknown})" ;;
        esac
        exit 0
      fi

      # --- launch ----------------------------------------------------------------

      require_host
      DSH_ROOT=$(remote_root)
      [ -n "$DSH_ROOT" ] || die "cannot resolve the harness home on $HOST (is bash installed there?)"
      case "$DSH_ROOT" in *" "* | *"'"*) die "the harness home on $HOST has an unsupported path: $DSH_ROOT" ;; esac
      LOG="$DSH_ROOT/web-$SESSION.log"
      REMOTE_CREDS="$DSH_ROOT/.credentials.yaml"
      LOCAL_ROOT="''${DSH_HOME:-$HOME/.dsh}"
      LOCAL_CREDS="$LOCAL_ROOT/.credentials.yaml"

      if [ "''${DRY_RUN:-0}" = 1 ]; then
        printf 'host=%s session=%s dir=%s profile=%s log=%s base_port=%s sync_auth=%s\n' \
          "$HOST" "$SESSION" "$DIR" "$PROFILE" "$LOG" "$PORT_BASE" "$SYNC_AUTH"
        exit 0
      fi

      # Credentials travel inside the ssh channel, never over another transport and
      # never on a command line. The remote keeps its own copy when it is already
      # signed in: a dormant account on the worker is the operator's, not ours.
      sync_auth() {
        [ "$SYNC_AUTH" = never ] && return 0
        [ -r "$LOCAL_CREDS" ] || return 0
        if ! grep -qs 'deepseek-account-platform/default' "$LOCAL_CREDS"; then
          [ "$SYNC_AUTH" = always ] && printf 'dsh-remote: this client has no DeepSeek account to import; sign in through the Web UI\n' >&2
          return 0
        fi

        if [ "$SYNC_AUTH" != always ]; then
          local remote_signed
          remote_signed=$(remote "$REMOTE_CREDS" <<'REMOTE' 2>/dev/null || true
      if grep -qs 'deepseek-account-platform/default' "$1"; then printf 'SIGNED\n'; else printf 'UNSIGNED\n'; fi
      REMOTE
          )
          [ "$(printf '%s\n' "$remote_signed" | tail -1)" = SIGNED ] && return 0
        fi

        umask 077
        # shellcheck disable=SC2029 # these paths are expanded locally on purpose
        if ! ssh "''${SSH_BATCH[@]}" "$HOST" "umask 077; mkdir -p '$DSH_ROOT'; if [ -s '$REMOTE_CREDS' ]; then cp -p '$REMOTE_CREDS' '$REMOTE_CREDS.bak'; fi; cat > '$REMOTE_CREDS.tmp'" <"$LOCAL_CREDS"; then
          printf 'dsh-remote: could not import the credential; sign in through the Web UI instead\n' >&2
          return 0
        fi
        # shellcheck disable=SC2029
        ssh "''${SSH_BATCH[@]}" "$HOST" "chmod 600 '$REMOTE_CREDS.tmp' && mv '$REMOTE_CREDS.tmp' '$REMOTE_CREDS'" \
          || die "could not install the credential on $HOST"
        printf 'dsh-remote: imported this client'"'"'s DeepSeek account over ssh (%s)\n' "$HOST"
      }

      sync_auth

      start_session() {
        remote "$SESSION" "$DIR" "$PROFILE" "$LOG" <<'REMOTE' 2>/dev/null | sed -n 's/^DSHSTART://p' | tail -1
      session=$1 dir=$2 profile=$3 log=$4
      case "$dir" in
        "~") dir=$HOME ;;
        "~/"*) dir=''${HOME}/''${dir#'~/'} ;;
      esac
      mkdir -p "''${log%/*}"
      if [ "$profile" = web ]; then
        verb="web --no-open --host 127.0.0.1 --port 0"
      else
        verb="$profile"
      fi
      if command -v dsh >/dev/null 2>&1; then
        run="dsh ''${verb}"
      else
        run="nix --accept-flake-config shell github:numtide/llm-agents.nix#dsh --command dsh ''${verb}"
      fi
      if tmux has-session -t "$session" 2>/dev/null; then
        printf 'DSHSTART:reused\n'
        exit 0
      fi
      : >"$log"
      # tmux runs the pane command through `default-shell`; on this fleet that is
      # nushell, whose grammar rejects `2>&1`. Hand the pane to bash explicitly.
      if tmux new-session -d -s "$session" "bash -lc 'cd \"$dir\" && ''${run} 2>&1 | tee \"$log\"'" 2>/dev/null; then
        printf 'DSHSTART:started\n'
      else
        printf 'DSHSTART:failed\n'
      fi
      REMOTE
      }

      read_url() {
        remote "$LOG" <<'REMOTE' 2>/dev/null | sed -n 's/^DSHURL://p' | tail -1
      url=$(sed -n 's|^.*\(http://127\.0\.0\.1:[0-9][0-9]*/?token=[^ ]*\).*|\1|p' "$1" 2>/dev/null | tail -1)
      printf 'DSHURL:%s\n' "$url"
      REMOTE
      }

      port_open() {
        local out
        out=$(remote "$1" <<'REMOTE' 2>/dev/null || true
      if bash -c "exec 3<>/dev/tcp/127.0.0.1/$1" 2>/dev/null; then printf 'OPEN\n'; else printf 'CLOSED\n'; fi
      REMOTE
        )
        [ "$(printf '%s\n' "$out" | tail -1)" = OPEN ]
      }

      url_port() {
        local p=''${1#http://127.0.0.1:}
        printf '%s' "''${p%%/*}"
      }

      wait_url() {
        remote "$SESSION" "$LOG" <<'REMOTE' 2>/dev/null | sed -n 's/^DSHWAIT://p' | tail -1
      for _ in $(seq 1 120); do
        url=$(sed -n 's|^.*\(http://127\.0\.0\.1:[0-9][0-9]*/?token=[^ ]*\).*|\1|p' "$2" 2>/dev/null | tail -1)
        if [ -n "$url" ]; then printf 'DSHWAIT:url %s\n' "$url"; exit 0; fi
        if ! tmux has-session -t "$1" 2>/dev/null; then
          printf 'DSHWAIT:died\n'
          tail -n 5 "$2" 2>/dev/null
          exit 0
        fi
        sleep 1
      done
      printf 'DSHWAIT:timeout\n'
      REMOTE
      }

      session_alive() {
        local out
        out=$(remote "$1" <<'REMOTE' 2>/dev/null || true
      if tmux has-session -t "$1" 2>/dev/null; then printf 'ALIVE\n'; else printf 'GONE\n'; fi
      REMOTE
        )
        [ "$(printf '%s\n' "$out" | tail -1)" = ALIVE ]
      }

      show_log() {
        printf 'dsh-remote: last lines of %s on %s:\n' "$LOG" "$HOST" >&2
        remote "$LOG" <<'REMOTE' >&2 || true
      tail -n 8 "$1" 2>/dev/null
      REMOTE
      }

      STARTED=$(start_session)
      case "$STARTED" in
        reused | started) ;;
        *) die "could not start the harness session $SESSION on $HOST" ;;
      esac

      # Any profile but web prints no URL and needs no tunnel: attach to it. A pane
      # that exits at once (`acp` without a client, `headless` without a prompt) would
      # otherwise surface only as ssh's "can't find session".
      if [ "$PROFILE" != web ]; then
        sleep "''${DSH_SETTLE:-1}"
        if ! session_alive "$SESSION"; then
          show_log
          die "profile $PROFILE exited on $HOST before attaching"
        fi
        if ssh -t -o ConnectTimeout=10 "$HOST" "tmux attach -t '$SESSION'"; then
          exit 0
        fi
        show_log
        die "could not attach to $SESSION on $HOST"
      fi

      URL=""
      if [ "$STARTED" = reused ]; then
        URL=$(read_url)
        if [ -z "$URL" ] || ! port_open "$(url_port "$URL")"; then
          remote "$SESSION" <<'REMOTE' >/dev/null 2>&1 || true
      tmux kill-session -t "$1" 2>/dev/null || true
      REMOTE
          URL=""
        fi
      fi

      if [ -z "$URL" ]; then
        printf 'dsh-remote: starting the harness on %s (first run may build dsh)…\n' "$HOST"
        waited=$(wait_url)
        case "$waited" in
          "url "*) URL=''${waited#url } ;;
          died)
            show_log
            die "the harness exited on $HOST (attach: ssh -t $HOST tmux attach -t $SESSION)"
            ;;
          timeout)
            show_log
            die "no Web UI URL after 120s (attach: ssh -t $HOST tmux attach -t $SESSION)"
            ;;
          *) die "could not read the Web UI URL from $LOG on $HOST" ;;
        esac
      fi

      RPORT=$(url_port "$URL")
      LPORT=$PORT_BASE
      while ss -ltnH 2>/dev/null | awk '{print $4}' | grep -qE "[:.]''${LPORT}$"; do
        LPORT=$((LPORT + 1))
      done

      LOCAL_URL=''${URL/127.0.0.1:$RPORT/127.0.0.1:$LPORT}

      ssh -N -o BatchMode=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=20 -o ServerAliveCountMax=3 \
        -L "$LPORT:127.0.0.1:$RPORT" "$HOST" &
      FWD=$!
      cleanup() { kill "$FWD" 2>/dev/null || true; }
      trap cleanup EXIT

      CODE=""
      for _ in $(seq 1 60); do
        CODE=$(curl -s -o /dev/null -m 2 -w '%{http_code}' "$LOCAL_URL" 2>/dev/null || true)
        case "$CODE" in
          303 | 200) break ;;
        esac
        kill -0 "$FWD" 2>/dev/null || die "the ssh tunnel to $HOST:$RPORT exited during setup"
        sleep 0.25
      done
      case "$CODE" in
        303 | 200) ;;
        *) die "the harness did not answer through the tunnel (last HTTP status: ''${CODE:-none})" ;;
      esac

      open_url() {
        local url=$1 cmd
        if [ -n "''${DSH_BROWSER:-}" ]; then
          # shellcheck disable=SC2086
          set -- ''${DSH_BROWSER}
          nohup "$@" "$url" >/dev/null 2>&1 &
          return 0
        fi
        if [ -n "''${BROWSER:-}" ]; then
          # shellcheck disable=SC2086
          set -- ''${BROWSER}
          nohup "$@" "$url" >/dev/null 2>&1 &
          return 0
        fi
        # xdg-open answers whether this session actually has a desktop; a browser
        # binary launched directly does not, so it is the fallback, not the default.
        if command -v xdg-open >/dev/null 2>&1 && timeout 10 xdg-open "$url" >/dev/null 2>&1; then
          return 0
        fi
        if command -v wslview >/dev/null 2>&1 && timeout 10 wslview "$url" >/dev/null 2>&1; then
          return 0
        fi
        for cmd in zen firefox chromium chromium-browser brave google-chrome; do
          command -v "$cmd" >/dev/null 2>&1 || continue
          nohup "$cmd" "$url" >/dev/null 2>&1 &
          return 0
        done
        return 1
      }

      if [ "$OPEN_BROWSER" = 1 ]; then
        if open_url "$LOCAL_URL"; then
          printf 'dsh-remote: opened %s\n' "$LOCAL_URL"
        else
          printf 'dsh-remote: no browser available here; open this URL yourself:\n\n  %s\n\n' "$LOCAL_URL" >&2
        fi
      else
        printf 'dsh-remote: open %s\n' "$LOCAL_URL"
      fi
      printf 'dsh-remote: tunnel localhost:%s -> %s:127.0.0.1:%s\n' "$LPORT" "$HOST" "$RPORT"
      printf 'dsh-remote: detaching the session below closes the tunnel.\n'

      ssh -t -o ConnectTimeout=10 "$HOST" "tmux attach -t '$SESSION'" || true

      printf '\ndsh-remote: tunnel closed; the session is still running on %s.\n' "$HOST"
      printf 'dsh-remote: run dsh-remote again to reconnect.\n'
    '';
  };

  # Local entry, only where the harness is actually installed (tier "full").
  dshLocal = pkgs.writeShellApplication {
    name = "dsh-local";
    runtimeInputs = [pkgs.llm-agents.dsh];
    text = ''
      set -euo pipefail
      TITLE="DeepSeek Harness (local)"
      if command -v kitty >/dev/null 2>&1; then
        exec kitty --title "$TITLE" -e dsh web
      elif command -v alacritty >/dev/null 2>&1; then
        exec alacritty -T "$TITLE" -e dsh web
      else
        exec "''${TERMINAL:-xterm}" -e dsh web
      fi
    '';
  };

  desktop = label: comment: exec: keywords: ''
    [Desktop Entry]
    Type=Application
    Name=${label}
    GenericName=Agent Harness
    Comment=${comment}
    Exec=${exec}
    Icon=deepseek
    Terminal=false
    Categories=Development;Utility;
    Keywords=${keywords};
  '';
in
  lib.mkIf (config.profiles.ai.enable && isLinux) {
    home.packages = [dshRemote] ++ lib.optional (config.profiles.ai.tier == "full") dshLocal;

    home.file =
      {
        ".local/share/icons/hicolor/256x256/apps/deepseek.png".source = iconFile;
        ".local/share/applications/dsh-remote.desktop".text = desktop "DeepSeek Harness (Remote)" "Run dsh web on the remote worker and open it in this browser" "dsh-remote" "ai;agent;dsh;deepseek;remote;browser";
      }
      // lib.optionalAttrs (config.profiles.ai.tier == "full") {
        ".local/share/applications/dsh.desktop".text = desktop "DeepSeek Harness" "Start the local harness and open its web UI" "dsh-local" "ai;agent;dsh;deepseek;local";
      };
  }
