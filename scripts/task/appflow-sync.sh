#!/usr/bin/env bash
# appflow-sync.sh — `appflow-sync` for any tailnet client, not only delphi.
#
# The packaged binary in modules/plugins/appflow/default.nix bakes the loopback
# API because it ships to the archive host. Everywhere else the same sync.py
# speaks the tailnet front, so this wrapper passes the API sync.py's argparse
# already reads from $EMAIL_ARCHIVE_API and nothing else changes. Draft verbs
# still need himalaya and its config on the host that runs them — the draft
# lands in the same mailbox regardless of where himalaya runs.
#
#   appflow-sync.sh --report | --update ID --status S [--next N]
#   appflow-sync.sh --file apps.json [--link] | --export OUT
#   appflow-sync.sh --sync [--apply] | --draft ID --body F [--apply] | --drafts
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cli=$repo/modules/plugins/appflow/sync.py
api=${EMAIL_ARCHIVE_API:-${APPFLOW_API:-https://delphi.cloudforest-kardashev.ts.net:8450}}
himalaya_config=${HIMALAYA_CONFIG:-$HOME/.config/himalaya/config.toml}

args=(--api "$api" --himalaya-config "$himalaya_config" "$@")

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$cli" "${args[@]}"
fi

exec nix-shell -p python3 --run "python3 $(printf '%q ' "$cli" "${args[@]}")"
