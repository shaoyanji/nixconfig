#!/usr/bin/env bash
# edge-serve.sh — bring the resident edge caller up on the surface a call will use.
#
# The unit that starts this at login must boot the sidecar with exactly the tool
# file `toolcall.sh` looks for, or the first call after login pays a weights load
# (the sidecar restarts when the surface it booted with changes) and the residency
# claim is false in the only moment it matters. So the path is ASKED FOR, never
# recomputed: `--tools-path` writes it if missing and prints it.
#
# EDGE_IDLE_SECONDS=0 by default: a login unit that reaps itself after 30 minutes
# is a lazy start with extra steps. `edge-check.sh` sets its own window when it
# wants the process gone.
#
# Usage: edge-serve.sh [status]     exit 0 = up, 1 = the sidecar did not come up,
#                                   2 = no engine/weights or no graph.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
export EDGE_IDLE_SECONDS="${EDGE_IDLE_SECONDS:-0}"
# The tool surface is a flake attribute addressed RELATIVE to the checkout, and a
# systemd user unit starts in $HOME: without this the graph "did not evaluate" and
# the unit failed at login (measured 2026-11-02, `edge-caller` exit 2 on first
# activation). Callers from any directory get the same behaviour.
cd "$REPO"

if [ "${1:-serve}" = status ]; then
  exec bash "$REPO/scripts/task/edge-sidecar.sh" status
fi

TOOLS="$(bash "$REPO/scripts/task/toolcall.sh" --tools-path)" || {
  echo "edge-serve: the tool surface did not derive (no graph?)" >&2
  exit 2
}
[ -s "$TOOLS" ] || {
  echo "edge-serve: tool surface is empty: $TOOLS" >&2
  exit 2
}
exec bash "$REPO/scripts/task/edge-sidecar.sh" ensure "$TOOLS"
