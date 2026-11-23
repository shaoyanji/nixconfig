#!/usr/bin/env bash
# kg-zeck.sh — inspect or force the opt-in incremental graph cache.
set -euo pipefail
REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
export REPO
# shellcheck source=lib/kg-elixir.sh
. "${BASH_SOURCE[0]%/*}/lib/kg-elixir.sh"
elixir="$(kg_resolve_elixir)" || { echo 'kg-zeck: Elixir unavailable' >&2; exit 1; }
exec "$elixir" "$REPO/tools/kg-zeck/cli.exs" "${@:-status}"
