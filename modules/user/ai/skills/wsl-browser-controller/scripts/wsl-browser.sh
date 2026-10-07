#!/usr/bin/env bash
set -euo pipefail

# Find Windows PowerShell binary
POWERSHELL_BIN="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
if [ ! -x "$POWERSHELL_BIN" ]; then
  POWERSHELL_BIN=$(which powershell.exe 2>/dev/null || echo "")
fi

if [ -z "$POWERSHELL_BIN" ] || [ ! -x "$POWERSHELL_BIN" ]; then
  echo "Error: powershell.exe not found. This tool requires WSL2 with Windows interop enabled." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS_SCRIPT="$SCRIPT_DIR/wsl-browser.ps1"
WIN_PS_SCRIPT=$(wslpath -w "$PS_SCRIPT")

show_help() {
  cat <<EOF
WSL Browser Controller - Inspect & Control Windows Chrome / Edge from WSL2

Usage:
  wsl-browser list [--json]           List all open tabs across Chrome/Edge
  wsl-browser active [--json]         Show the currently active/focused tab
  wsl-browser focus <index|keyword>   Switch to and bring tab/window to front
  wsl-browser close <index|keyword>   Close a tab by index or title keyword
  wsl-browser open <url>              Open a URL in the default Windows browser
  wsl-browser help                    Show this help message

Examples:
  wsl-browser list
  wsl-browser list --json
  wsl-browser active
  wsl-browser focus 3
  wsl-browser focus "GitHub"
  wsl-browser open "https://github.com"
  wsl-browser close "Stirling"
EOF
}

CMD="${1:-list}"

case "$CMD" in
  list)
    JSON_FLAG=""
    if [[ "${2:-}" == "--json" ]]; then
      JSON_FLAG="-Json"
    fi
    "$POWERSHELL_BIN" -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS_SCRIPT" list "" $JSON_FLAG < /dev/null
    ;;
  active)
    JSON_FLAG=""
    if [[ "${2:-}" == "--json" ]]; then
      JSON_FLAG="-Json"
    fi
    "$POWERSHELL_BIN" -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS_SCRIPT" active "" $JSON_FLAG < /dev/null
    ;;
  focus)
    TARGET="${2:-}"
    if [ -z "$TARGET" ]; then
      echo "Error: Missing tab index or keyword." >&2
      exit 1
    fi
    "$POWERSHELL_BIN" -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS_SCRIPT" focus "$TARGET" < /dev/null
    ;;
  close)
    TARGET="${2:-}"
    if [ -z "$TARGET" ]; then
      echo "Error: Missing tab index or keyword." >&2
      exit 1
    fi
    "$POWERSHELL_BIN" -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS_SCRIPT" close "$TARGET" < /dev/null
    ;;
  open)
    URL="${2:-}"
    if [ -z "$URL" ]; then
      echo "Error: Missing URL." >&2
      exit 1
    fi
    "$POWERSHELL_BIN" -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS_SCRIPT" open "$URL" < /dev/null
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    show_help
    exit 1
    ;;
esac
