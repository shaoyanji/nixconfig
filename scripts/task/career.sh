#!/usr/bin/env bash
# career.sh — run the career authoring CLI from this checkout.
#
# The tool is a single Python file with no dependencies, so it runs anywhere the
# repo is; the wrapper exists only because python3 is not on every host's base
# PATH (taskfiles/apps.yml carries the same note for the workflow's CLI). The
# API is on delphi's tailnet mount, so the command line works from a workstation
# and from the host without a second copy of the script.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cli=$repo/modules/plugins/appflow/career.py

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$cli" "$@"
fi

# `nix-shell --run` takes one string, so the arguments are quoted into it rather
# than interpolated unquoted.
exec nix-shell -p python3 --run "python3 $(printf '%q ' "$cli" "$@")"
