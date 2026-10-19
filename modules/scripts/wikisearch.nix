# wikisearch — universal offline wiki search over Kiwix-served ZIM archives.
#
# Moved out of hosts/frieren/tools.nix (2026-10-19): a 200-line program is a
# program, and modules/scripts/ is where the fleet keeps its packaged scripts
# (cf. pb.nix). The host module now only says "this host ships it".
{pkgs, ...}:
pkgs.writeShellApplication {
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
      # kiwix-serve is a SYSTEM service (services.kiwix-serve, modules/services/kiwix.nix)
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

      # 2. Declarative library (modules/services/kiwix.nix): books are
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
}
