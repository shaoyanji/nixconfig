#!/usr/bin/env bash
# pins-refresh.sh — refresh the small pinned datasets, and nothing large.
#
# `lib/pins.toml` is the registry: one file per pin, the command that refreshes
# it, and the size it must stay under. The refresh runs here, outside Nix,
# because the sources are the tailnet shim and a gist: neither is reachable from
# a build sandbox, and a build that needs the network is not a build. What Nix
# reads is the committed file, so the tree stays pure and the data stays fresh at
# the moment it is pushed.
#
# A refresh that fails (no token, no $HOME resume, gist unreachable) is SKIPPED
# and named on stderr: a push must not fail because one source was unavailable,
# and a silent skip would be worse than a loud one.
#
# Two kinds of entry. A `[[pin]]` is a file in the tree, refreshed by its `cmd`.
# A `[[hash]]` is a fetch with no file here — a gist a shell reads, the SSH key
# list — where the hash is the whole pin, so every run re-reads it.
#
# Usage
#   pins-refresh.sh            refresh, print what changed
#   pins-refresh.sh --check    exit 1 when a pin is stale, without writing
#   pins-refresh.sh --commit   refresh and commit the changed pins
#
# Env
#   PINS=   registry path (default lib/pins.toml)
#   PIN_TIMEOUT=  seconds per refresh (default 120)
#
# Task: agents:pins:refresh · called by .githooks/pre-push
set -uo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
PINS=${PINS:-$ROOT/lib/pins.toml}
TIMEOUT=${PIN_TIMEOUT:-120}
mode=${1:---refresh}

[ -f "$PINS" ] || { printf 'pins: no registry at %s\n' "$PINS" >&2; exit 2; }

command -v yq >/dev/null || { printf 'pins: yq is not on PATH\n' >&2; exit 2; }

rows=$(yq -p toml -o json '.pin' "$PINS" | jq -r '.[] | [.name, .path, .cmd, (.max_bytes|tostring), (.hash_key // "")] | @tsv') || {
  printf 'pins: could not read %s\n' "$PINS" >&2
  exit 2
}

hash_rows=$(yq -p toml -o json '.hash // []' "$PINS" | jq -r '.[] | [.key, (.file // "modules/config/fetches.json")] | @tsv') || {
  printf 'pins: could not read the [[hash]] table in %s\n' "$PINS" >&2
  exit 2
}

changed=()
skipped=()

# Rewrite one entry's sha256 in a fetch registry and stage the file when its
# bytes changed. The comparison is the file against itself: a hash repaired back
# to the committed value is a rewrite, and comparing with HEAD would call it
# unchanged.
refresh_hash() { # name key file
  local name="$1" key="$2" file="$3" before after log
  before=$(sha256sum "$ROOT/$file" | cut -d' ' -f1)
  if log=$(bash "$ROOT/scripts/task/nix-hash-update.sh" "$ROOT/$file" "$key" 2>&1); then
    after=$(sha256sum "$ROOT/$file" | cut -d' ' -f1)
    if [ "$before" = "$after" ]; then
      printf 'HASH   %-12s %-20s unchanged\n' "$name" "$key"
    else
      git -C "$ROOT" add -- "$file"
      printf 'HASH   %-12s %-20s rewritten\n' "$name" "$key"
      changed+=("$key")
    fi
  else
    printf 'HASH   %-12s %-20s could not be re-hashed: %s\n' "$name" "$key" "$(tail -1 <<<"$log")" >&2
  fi
}

while IFS=$'\t' read -r name path cmd max hash_key; do
  [ -n "$name" ] || continue
  file="$ROOT/$path"

  if [ "$mode" = --check ]; then
    if [ -f "$file" ] && git -C "$ROOT" diff --quiet -- "$path" 2>/dev/null &&
      git -C "$ROOT" diff --cached --quiet -- "$path" 2>/dev/null; then
      continue
    fi
    printf 'STALE  %-12s %s\n' "$name" "$path"
    changed+=("$name")
    continue
  fi

  if ! (cd "$ROOT" && timeout "$TIMEOUT" bash -c "$cmd") >/tmp/pins-"$name".log 2>&1; then
    printf 'SKIP   %-12s %s\n' "$name" "$(tail -1 /tmp/pins-"$name".log 2>/dev/null)"
    skipped+=("$name")
    continue
  fi

  [ -f "$file" ] || { printf 'SKIP   %-12s %s missing after refresh\n' "$name" "$path"; skipped+=("$name"); continue; }
  size=$(wc -c <"$file")
  if [ "$size" -gt "$max" ]; then
    printf 'LARGE  %-12s %s bytes > %s: not a pin, leave it out of the tree\n' "$name" "$size" "$max" >&2
    skipped+=("$name")
    continue
  fi

  if git -C "$ROOT" diff --quiet -- "$path" 2>/dev/null &&
    git -C "$ROOT" diff --cached --quiet -- "$path" 2>/dev/null; then
    printf 'FRESH  %-12s %s\n' "$name" "$path"
  else
    git -C "$ROOT" add -- "$path"
    printf 'PIN    %-12s %s (%s bytes)\n' "$name" "$path" "$size"
    changed+=("$name")
  fi

  # The same source is often a Nix fetch as well, and Nix pins the bytes, not
  # the URL: a refreshed pin with a stale hash fails the build that reads it.
  # Both files travel in one commit, so this runs whether or not the pin itself
  # moved — FRESH only means this file matches HEAD, not that the hash does.
  if [ -n "$hash_key" ]; then
    refresh_hash "$name" "$hash_key" modules/config/fetches.json
  fi
done <<<"$rows"

# The fetches with no pinned file of their own: nothing to compare, so read the
# upstream hash and stage the registry when it moved. Skipped in --check, which
# stays offline and file-only because pre-push runs it.
if [ "$mode" != --check ]; then
  while IFS=$'\t' read -r key file; do
    [ -n "$key" ] || continue
    refresh_hash fetch "$key" "$file"
  done <<<"$hash_rows"
fi

if [ "$mode" = --check ]; then
  [ ${#changed[@]} -eq 0 ] || { printf 'pins: %d stale — task pins:refresh\n' "${#changed[@]}" >&2; exit 1; }
  printf 'pins: all fresh\n'
  exit 0
fi

if [ ${#changed[@]} -eq 0 ]; then
  printf 'pins: nothing to refresh (%d skipped)\n' "${#skipped[@]}"
  exit 0
fi

if [ "$mode" = --commit ]; then
  git -C "$ROOT" commit -m "pins: refresh ${changed[*]}" >/tmp/pins-commit.log 2>&1 &&
    printf 'pins: committed %s\n' "${changed[*]}" ||
    { printf 'pins: commit failed, see /tmp/pins-commit.log\n' >&2; exit 1; }
fi

printf 'pins: %d refreshed, %d skipped\n' "${#changed[@]}" "${#skipped[@]}"
