#!/usr/bin/env bash
# content.sh — run a content authoring CLI (career, portfolio) from this checkout.
#
# The tools are single Python files with no dependencies, so they run anywhere
# the repo is; this wrapper exists only because python3 is not on every host's
# base PATH (taskfiles/apps.yml carries the same note for the workflow's CLI).
# The API is on delphi's tailnet mount, so the same command line works from a
# workstation and from the host.
set -euo pipefail

tool=${1:-}
case "$tool" in
  career | portfolio) ;;
  *)
    echo "usage: content.sh <career|portfolio> [args…]" >&2
    exit 2
    ;;
esac
shift

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cli=$repo/modules/plugins/appflow/$tool.py

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$cli" "$@"
fi

# `nix-shell --run` takes one string, so the arguments are quoted into it rather
# than interpolated unquoted.
exec nix-shell -p python3 --run "python3 $(printf '%q ' "$cli" "$@")"
