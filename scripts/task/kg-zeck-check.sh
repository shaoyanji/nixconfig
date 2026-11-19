#!/usr/bin/env bash
# kg-zeck-check.sh — isolated worktree parity; never touches a fleet host.
set -euo pipefail
REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
export REPO
# shellcheck source=lib/kg-elixir.sh
. "${BASH_SOURCE[0]%/*}/lib/kg-elixir.sh"
elixir="$(kg_resolve_elixir)" || { echo 'kg-zeck: Elixir unavailable' >&2; exit 1; }
export KG_ELIXIR="$elixir"
"$elixir" "$REPO/tools/kg-zeck/kg_zeck_test.exs"
exec "$elixir" "$REPO/tools/kg-zeck/parity.exs"
