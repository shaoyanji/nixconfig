#!/usr/bin/env bash
# apps-resolve.sh — attribute or close the appflow queue.
#
# The full run happens on delphi: the archive API and the two System One engines
# are loopback there, and appflow-resolve.service already drains the queue after
# every sync. Run from a client this still resolves what the rules can prove —
# the engines and the hermes batch are skipped automatically when loopback does
# not answer, and the unsures wait for the timer instead of failing the run.
#
# DRY is the default; --apply writes. The flags go through CLI_ARGS:
#   task apps:queue:resolve -- --limit 200
#   task apps:queue:resolve -- --apply
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cli=$repo/modules/plugins/appflow/resolve.py
api=${EMAIL_ARCHIVE_API:-${APPFLOW_API:-https://delphi.cloudforest-kardashev.ts.net:8450}}

args=(--api "$api")

# The System One engines answer on loopback only. Where they do not, resolve is
# rules + defer: everything provable still closes, and nothing waits on a
# connection that was never going to open.
if ! curl -sI --max-time 3 -o /dev/null "http://127.0.0.1:8091/" 2>/dev/null; then
  case " $* " in
    *--no-model* | *--no-hermes*) ;;
    *)
      args+=(--no-model --no-hermes)
      echo "apps-resolve: decision engines unreachable — rules only, ambiguous mail stays queued" >&2
      ;;
  esac
fi

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$cli" "${args[@]}" "$@"
fi

exec nix-shell -p python3 --run "python3 $(printf '%q ' "$cli" "${args[@]}" "$@")"
