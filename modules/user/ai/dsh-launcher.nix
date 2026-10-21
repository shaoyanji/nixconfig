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

  # Remote harness on the ARM bastion. Public SSH (delphi.bountystash.com),
  # NOT Tailscale SSH: the tailnet path triggers a browser device check that
  # turns an unattended launch into a five-minute hang.
  #
  # The -L forward is the point of web mode: `dsh web` prints a URL with a
  # one-time token bound to 127.0.0.1:<port> on the VM, so forwarding that same
  # port makes the printed URL work verbatim in the local browser.
  dshRemote = pkgs.writeShellApplication {
    name = "dsh-remote";
    runtimeInputs = [pkgs.openssh pkgs.coreutils];
    text = ''
      set -euo pipefail
      HOST="''${DSH_HOST:-delphi.bountystash.com}"
      SESSION="''${DSH_SESSION:-dsh}"
      PORT="''${DSH_PORT:-3080}"
      DIR="''${DSH_DIR:-~}"
      MODE="web"

      while [ $# -gt 0 ]; do
        case "$1" in
          -C | --dir) DIR="$2"; shift 2 ;;
          --host) HOST="$2"; shift 2 ;;
          --tui) MODE="tui"; shift ;;
          --new) SESSION="$SESSION-$(date +%s)"; shift ;;
          --status)
            exec ssh -t "$HOST" "tmux ls 2>/dev/null || echo 'no harness session'"
            ;;
          --kill)
            ssh -t "$HOST" "tmux kill-session -t '$SESSION' 2>/dev/null || true"
            echo "killed $SESSION on $HOST"
            exit 0
            ;;
          -h | --help)
            echo "dsh-remote — run the DeepSeek Harness on delphi in tmux"
            echo ""
            echo "  dsh-remote                     web UI, port-forwarded to localhost:3080"
            echo "  dsh-remote --tui               terminal UI instead (no forward)"
            echo "  dsh-remote -C ~/src/project    start the harness in another directory"
            echo "  dsh-remote --new               force a fresh session instead of attaching"
            echo "  dsh-remote --status            list harness sessions on the host"
            echo "  dsh-remote --kill              kill the session"
            echo "  dsh-remote --host <h>          another host (default delphi.bountystash.com)"
            echo ""
            echo "Env: DSH_HOST DSH_SESSION DSH_PORT DSH_DIR"
            echo "DRY_RUN=1 prints the ssh argv without connecting."
            exit 0
            ;;
          *) echo "dsh-remote: unknown argument $1" >&2; exit 2 ;;
        esac
      done

      case "$DIR" in
        *" "*) echo "dsh-remote: a directory with spaces is not supported" >&2; exit 2 ;;
      esac

      # No inner double quotes: the nix fallback uses --command, so the tmux
      # argument survives one level of quoting without escaping.
      REMOTE="tmux new-session -A -s '$SESSION' \"bash -lc 'cd $DIR && if command -v dsh >/dev/null 2>&1; then exec dsh $MODE; else exec nix --accept-flake-config shell github:numtide/llm-agents.nix#dsh --command dsh $MODE; fi'\""

      SSH_ARGS=(-t)
      if [ "$MODE" = web ]; then
        SSH_ARGS+=(-L "$PORT:127.0.0.1:$PORT")
      fi

      if [ "''${DRY_RUN:-0}" = 1 ]; then
        printf 'ssh %s %s %s\n' "''${SSH_ARGS[*]}" "$HOST" "$REMOTE"
        exit 0
      fi

      TITLE="DeepSeek Harness ($HOST)"
      if command -v kitty >/dev/null 2>&1; then
        exec kitty --title "$TITLE" -e ssh "''${SSH_ARGS[@]}" "$HOST" "$REMOTE"
      elif command -v alacritty >/dev/null 2>&1; then
        exec alacritty -T "$TITLE" -e ssh "''${SSH_ARGS[@]}" "$HOST" "$REMOTE"
      else
        exec "''${TERMINAL:-xterm}" -e ssh "''${SSH_ARGS[@]}" "$HOST" "$REMOTE"
      fi
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
        ".local/share/applications/dsh-remote.desktop".text = desktop "DeepSeek Harness (Remote)" "Run dsh web on the ARM bastion in tmux, forwarded to localhost" "dsh-remote" "ai;agent;dsh;deepseek;delphi;remote";
      }
      // lib.optionalAttrs (config.profiles.ai.tier == "full") {
        ".local/share/applications/dsh.desktop".text = desktop "DeepSeek Harness" "Start the local harness and open its web UI" "dsh-local" "ai;agent;dsh;deepseek;local";
      };
  }
