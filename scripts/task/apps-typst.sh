#!/usr/bin/env bash
# apps-typst.sh <followups|build|audit|git-status> [args]
#
# These verbs belong to the workflow checkout, which exists only where
# /srv/data is mounted. With the mount this runs bin/appflow locally, as the
# apps:* tasks always did; without it the command is delegated to frieren —
# the mount's host — over ssh, so the same call works on delphi or any client
# instead of dying at exit 127 on a missing path. The probe is bounded, so a
# host with neither transport answers no in seconds. APPS_DIR/APPS_HOST move
# both the mount and the delegate.
set -euo pipefail

apps_dir="${APPS_DIR:-/srv/data/projects/antigravity-application-workflow}"
apps_host="${APPS_HOST:-frieren}"
verb="${1:?usage: apps-typst.sh <followups|build|audit|git-status> [args]}"
shift || true

quote() { printf '%q ' "$@"; }

case "$verb" in
followups | build | audit)
  run="$(quote "$apps_dir/bin/appflow" "$verb" "$@")"
  ;;
git-status)
  run="$(quote git -C "$apps_dir" status -sb)"
  ;;
*)
  echo "apps-typst: unknown verb '$verb'" >&2
  exit 64
  ;;
esac

if [ -x "$apps_dir/bin/appflow" ]; then
  exec nix-shell -p python3 --run "$run"
fi

if ! ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$apps_host" true 2>/dev/null; then
  echo "apps-$verb: no checkout at $apps_dir on this host, and $apps_host is not answering ssh" >&2
  echo "apps-$verb: the Typst checkout is mounted where /srv/data is — task apps:doctor says which transports this host has" >&2
  exit 127
fi
exec ssh -n -o BatchMode=yes "$apps_host" "$run"
