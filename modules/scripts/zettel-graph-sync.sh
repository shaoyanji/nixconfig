#!/usr/bin/env bash
# One run = one generation of @wwwDir@: the private reader's page and a
# graph.json exported by the vault's own exporter. The token arrives as a
# systemd credential, is written into a store file for this run only, and never
# reaches argv, .git/config or the journal.
set -euo pipefail

export HOME="@stateDir@"
umask 0027

token_file="${CREDENTIALS_DIRECTORY:?the unit must LoadCredential github-token}/github-token"
creds="$(mktemp)"
trap 'rm -f "$creds"' EXIT
chmod 600 "$creds"
printf 'https://x-access-token:%s@github.com\n' "$(cat "$token_file")" > "$creds"
AUTH=(-c "credential.helper=store --file=$creds")

# The remote carries no secret: a token in the URL would be copied into
# .git/config and outlive the unit.
ensure_repo() {
  local url="$1" dir="$2"
  if [ ! -d "$dir/.git" ]; then
    mkdir -p "$dir"
    git -C "$dir" init --quiet
    git -C "$dir" remote add origin "$url"
  elif ! git -C "$dir" remote get-url origin >/dev/null 2>&1; then
    git -C "$dir" remote add origin "$url"
  fi
  git -C "$dir" "${AUTH[@]}" fetch --quiet origin "$3"
}

# The reader is never edited on this host, so a new origin is simply checked out
# over whatever was there.
sync_reader() {
  ensure_repo "@frontendUrl@" "@frontendDir@" "@frontendRef@"
  git -C "@frontendDir@" reset --hard --quiet FETCH_HEAD
}

# The vault is edited on this host: a page write leaves a local commit. So this
# merges, and pushes what the page wrote instead of reverting it. A tree that
# has diverged is left exactly as it is and named in the journal — losing a note
# to a timer is the one failure this service must not have.
sync_vault() {
  ensure_repo "@vaultUrl@" "@vaultDir@" "@vaultRef@"
  if ! git -C "@vaultDir@" rev-parse --verify --quiet HEAD >/dev/null; then
    git -C "@vaultDir@" checkout --quiet --detach FETCH_HEAD
    return
  fi
  if git -C "@vaultDir@" merge-base --is-ancestor HEAD FETCH_HEAD; then
    git -C "@vaultDir@" merge --ff-only --quiet FETCH_HEAD
  elif git -C "@vaultDir@" merge-base --is-ancestor FETCH_HEAD HEAD; then
    git -C "@vaultDir@" "${AUTH[@]}" push --quiet origin "HEAD:refs/heads/@vaultRef@"
  else
    echo "vault: local tree diverged from origin/@vaultRef@; serving it as it is" >&2
  fi
}

sync_reader
sync_vault

mkdir -p "@wwwDir@"
tmp="@wwwDir@/.graph.$$.json"
trap 'rm -f "$creds" "$tmp"' EXIT

# Export to a temporary name and move it into place, so a failed export leaves
# the previous graph.json serving instead of a half-written one.
(cd "@vaultDir@" && "@python@" scripts/export_graph.py --out "$tmp")
mv -f "$tmp" "@wwwDir@/graph.json"

install -m 0644 "@frontendDir@/index.html" "@wwwDir@/index.html"
if [ -d "@frontendDir@/demo" ]; then
  rm -rf "@wwwDir@/demo"
  cp -a "@frontendDir@/demo" "@wwwDir@/demo"
fi
