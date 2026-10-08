# Remote paste bin: pastes land on frieren over SSH, served read-only by
# nginx at http://paste.frieren.lan (LAN + Tailscale only — no auth, so treat
# pastes as LAN-visible; 8-char random names + 30-day tmpfiles expiry).
#
# CLI: `pb` (coreutils already ships a `paste` utility — do not shadow it).
# Installed for devji at ~/.local/bin/pb. Upload streams stdin/file over SSH;
# `pb list` / `pb rm NAME` manage pastes. Override the target with
# PASTE_SSH_TARGET (default devji@192.168.3.25 — an IP, because frieren
# cannot resolve its own .lan name) so the same wrapper works from any fleet
# host that has devji SSH access.
#
# DNS: covered by the dnsmasq wildcard (address=/frieren.lan/192.168.3.25);
# firewall: port 80 already open via reverse-proxy.nix.
{pkgs, ...}: let
  user = import ../global/user.nix;

  # writers.writeBashBin (fleet pattern, cf. modules/scripts/default.nix):
  # writeShellApplication would dispatch shellcheck to nixbuild.net where it
  # fails in their sandbox. The script is verified with shellcheck manually
  # (passes clean, 2026-10-08).
  pb = pkgs.writers.writeBashBin "pb" ''
    # SC2029: the ssh command strings are expanded client-side on purpose.
    # $DIR is fixed, and every interpolated name is validated by valid_name
    # first, so no spaces or shell metacharacters reach the remote shell
    # (fleet convention: cf. freebuff-remote.nix's remote ssh strings).
    # shellcheck disable=SC2029
    set -euo pipefail

    # IP default: frieren cannot resolve its own .lan name (dnsmasq serves
    # the LAN, not its own resolver); first use per machine accepts the
    # host key once.
    TARGET="''${PASTE_SSH_TARGET:-devji@192.168.3.25}"
    BASE_URL="''${PASTE_BASE_URL:-http://paste.frieren.lan}"
    DIR="/var/lib/paste"

    usage() {
      cat <<'USAGE'
    pb — fleet paste bin (http://paste.frieren.lan)

    Usage:
      pb [FILE [NAME]]    Upload a file (or stdin if FILE is -) under an
                          8-char random name (NAME overrides it).
      pb                  With piped stdin: upload stdin.
      pb clip [NAME]      Upload current clipboard contents (or pb -c).
      pb list             List pastes on frieren.
      pb rm NAME          Delete a paste.
      pb url NAME         Print the URL for NAME.

    Env:
      PASTE_SSH_TARGET    SSH target (default: devji@192.168.3.25)
      PASTE_BASE_URL      Base URL (default: http://paste.frieren.lan)
    USAGE
    }

    # Names become remote filenames inside an ssh command line — keep them
    # boring: no spaces, slashes or shell metacharacters.
    valid_name() {
      [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
    }

    gen_name() {
      # Under pipefail, `head -c 8` exits once it has its bytes and tr
      # gets SIGPIPE (status 141) — expected, so mask the pipeline status.
      tr -dc a-z0-9 </dev/urandom | head -c 8 || :
    }

    ensure_display() {
      if [ -z "''${WAYLAND_DISPLAY:-}" ] && [ -n "''${XDG_RUNTIME_DIR:-}" ]; then
        for sock in "$XDG_RUNTIME_DIR"/wayland-*; do
          if [ -S "$sock" ]; then
            export WAYLAND_DISPLAY="''${sock##*/}"
            break
          fi
        done
      fi
      if [ -z "''${DISPLAY:-}" ] && [ -S "/tmp/.X11-unix/X0" ]; then
        export DISPLAY=":0"
      fi
    }

    clip() {
      local name="''${1:-}"
      ensure_display
      if command -v wl-paste >/dev/null 2>&1 && wl-paste -n >/dev/null 2>&1; then
        wl-paste | upload - "$name"
      elif command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard -o | upload - "$name"
      else
        echo "pb: nothing in clipboard or no clipboard utility found (wl-paste/xclip)" >&2
        exit 1
      fi
    }

    upload() {
      local src="''${1:--}" name="''${2:-}" ext="" url=""
      if [[ "$src" != "-" ]]; then
        if [[ ! -f "$src" ]]; then
          echo "pb: no such file: $src" >&2
          exit 1
        fi
        if [[ -z "$name" ]]; then
          case "$src" in
            *.*) ext=".''${src##*.}" ;;
          esac
          # keep the extension only when it is filename-safe
          [[ "$ext" =~ ^\.[A-Za-z0-9]+$ ]] || ext=""
        fi
      fi
      if [[ -z "$name" ]]; then
        name="$(gen_name)''${ext}"
      fi
      if ! valid_name "$name"; then
        echo "pb: invalid name: $name (allowed: A-Z a-z 0-9 . _ -)" >&2
        exit 1
      fi

      if [[ "$src" == "-" ]]; then
        # stdin: ssh inherits our stdin, no redirect needed
        ssh "$TARGET" "mkdir -p $DIR && (umask 022; cat > $DIR/$name)"
      else
        ssh "$TARGET" "mkdir -p $DIR && (umask 022; cat > $DIR/$name)" < "$src"
      fi
      url="$BASE_URL/$name"
      echo "$url"
      # Best-effort clipboard copy (Wayland then X11).
      ensure_display
      if command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$url" | wl-copy >/dev/null 2>&1 || true
      elif command -v xclip >/dev/null 2>&1; then
        printf '%s' "$url" | xclip -selection clipboard >/dev/null 2>&1 || true
      fi
    }

    case "''${1:-}" in
      -h|--help|help)
        usage
        ;;
      list)
        ssh "$TARGET" "ls -lht $DIR"
        ;;
      rm|del)
        shift
        [[ ''${1:-} ]] || { echo "pb rm NAME" >&2; exit 1; }
        valid_name "$1" || { echo "pb: invalid name: $1" >&2; exit 1; }
        ssh "$TARGET" "rm -f $DIR/$1"
        echo "deleted: $1"
        ;;
      url)
        [[ ''${2:-} ]] || { echo "pb url NAME" >&2; exit 1; }
        valid_name "$2" || { echo "pb: invalid name: $2" >&2; exit 1; }
        echo "$BASE_URL/$2"
        ;;
      clip|-c|--clip)
        clip "''${2:-}"
        ;;
      -)
        upload - "''${2:-}"
        ;;
      "")
        # no args: piped stdin uploads, an interactive tty shows usage
        if [ ! -t 0 ]; then
          upload -
        else
          usage
        fi
        ;;
      *)
        upload "$1" "''${2:-}"
        ;;
    esac
  '';
in {
  # Paste storage + 30-day expiry (tmpfiles 'e' cleans files older than age).
  systemd.tmpfiles.rules = [
    "d /var/lib/paste 0755 devji users -"
    "e /var/lib/paste - - - 30d"
  ];

  services.nginx.virtualHosts."paste.frieren.lan" = {
    listen = [
      {
        addr = "0.0.0.0";
        port = 80;
      }
    ];
    locations."/" = {
      root = "/var/lib/paste";
      extraConfig = ''
        # No directory listings: /var/ has no index file, and an open
        # autoindex would enumerate every paste (names are the only gate).
        autoindex off;
        default_type text/plain;
      '';
    };
  };

  home-manager.users.${user.name}.home.file.".local/bin/pb" = {
    source = "${pb}/bin/pb";
  };
}
