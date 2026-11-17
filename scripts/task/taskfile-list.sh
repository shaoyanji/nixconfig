#!/usr/bin/env bash
# taskfile-list.sh — `task --list-all --json`, cached by what decides it.
#
# This is the control plane's most expensive read: go-task parses all 24
# shards and every task to answer it, measured **2.3-2.5 s** on delphi
# (2026-11-07) for 616 tasks. `task help` and `task find:<word>` are the
# documented way in (AGENTS.md § Entry contract), and each was paying that once plus the
# outer parse — 2.6 s to answer "which task". The same JSON is a pure function
# of the Taskfile tree and the go-task binary, so it is cached against exactly
# those: 9 ms to key, ~120 ms to read.
#
# Not a second source of truth: `scripts/task/taskfile-graph.sh` asks for
# `--refresh`, so the gate still judges the LIVE name set and rewrites this
# cache as a side effect (the pre-push hook runs it). A stale copy therefore
# cannot outlive one push, and nothing gates on the file.
#
# Usage: taskfile-list.sh [--refresh]
# Exit:  0 with the JSON on stdout · 1 go-task failed
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig"
refresh=0
case "${1:-}" in
  --refresh) refresh=1 ;;
  "") ;;
  *)
    echo "taskfile-list: unknown argument $1" >&2
    exit 2
    ;;
esac

# The key is the files go-task reads plus the binary's identity (a go-task
# upgrade changes the name set without touching a taskfile). `ls -lL` rather
# than `stat -c`, which is GNU-only and this tree also builds on darwin.
bin="$(command -v task || true)"
[ -n "$bin" ] || {
  echo "taskfile-list: task is not on PATH" >&2
  exit 1
}
key="$(
  cd "$REPO"
  {
    sha1sum Taskfile.yml taskfiles/*.yml
    ls -lL "$bin" | awk '{print $5, $6, $7, $8}'
  } | sha1sum | cut -c1-16
)"
path="$CACHE/tasks-$key.json"

if [ "$refresh" = 0 ] && [ -s "$path" ]; then
  cat "$path"
  exit 0
fi

mkdir -p "$CACHE"
# One temp file PER WRITER, then an atomic rename: a reader racing the parse
# must never see half a document. A single shared `.tmp` also let two refreshes
# clobber each other, which surfaced as `mv: cannot stat … .tmp` and a caller
# reading a truncated name set (measured: two `--refresh` runs at once).
tmp="$(mktemp "$path.XXXXXX")"
if ! (cd "$REPO" && task --list-all --json) >"$tmp" 2>/dev/null; then
  rm -f "$tmp"
  echo "taskfile-list: task --list-all --json failed" >&2
  exit 1
fi
mv "$tmp" "$path"
find "$CACHE" -maxdepth 1 -name 'tasks-*.json' -type f -mtime +7 -delete 2>/dev/null || true
cat "$path"
