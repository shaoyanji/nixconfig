#!/usr/bin/env bash
# apps-resolve.sh — attribute or close the appflow queue.
#
# Runs on delphi: the archive API and the two System One engines are loopback
# there. DRY is the default; APPLY=1 writes. The flags go through CLI_ARGS:
#   task apps:queue:resolve -- --limit 200
#   task apps:queue:resolve -- --apply
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cli=$repo/modules/plugins/appflow/resolve.py

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$cli" "$@"
fi

exec nix-shell -p python3 --run "python3 $(printf '%q ' "$cli" "$@")"
