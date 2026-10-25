#!/usr/bin/env bash
# atuin bring-up for ONE fleet host, after its rebuild has rendered the key:
# login (if needed) -> seed shell history once -> sync -> report the count.
#
#   bash atuin-bootstrap.sh [--expect N] [--force-seed]
#
# Credentials: ATUIN_PASSWORD / ATUIN_KEY (the 24-word mnemonic) from the
# environment, else sops from the repo. Run it here, or pipe it:
#   ssh <host> 'bash -s' < .agents/skills/atuin/scripts/atuin-bootstrap.sh
#
# Exit: 0 ok · 2 not ready (no atuin / no key -> rebuild) · 3 no credentials
#       · 4 login or sync failed · 5 count != --expect
set -euo pipefail

EXPECT=""
FORCE_SEED=0
while [ $# -gt 0 ]; do
  case "$1" in
  --expect)
    EXPECT="${2:?--expect needs a number}"
    shift 2
    ;;
  --force-seed)
    FORCE_SEED=1
    shift
    ;;
  -h | --help)
    sed -n '2,14p' "$0"
    exit 0
    ;;
  *)
    echo "unknown flag: $1" >&2
    exit 2
    ;;
  esac
done

DATA="${ATUIN_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/atuin}"
KEYFILE="$DATA/key"
MARKER="$DATA/.fleet-seeded"
HOST="$(hostname)"

die() {
  echo "FAIL ($1): $2" >&2
  exit "$1"
}

# --- precondition: the binary and the declarative key ----------------------
command -v atuin >/dev/null || die 2 "atuin is not installed — rebuild this host"
[ -e "$KEYFILE" ] || die 2 "no key file at $KEYFILE — rebuild this host (modules/sops.nix renders it)"
KEYLEN=$(head -c 200 "$KEYFILE" | tr -d '[:space:]' | wc -c)
[ "$KEYLEN" -eq 60 ] || die 2 "$KEYFILE is $KEYLEN chars, not a 60-char base64 key — the mnemonic belongs in 'atuin login -k', not the key file"

# A host that did not get modules/shell/atuin.nix logs into the PUBLIC server and
# then 'invalid credentials', which looks exactly like a wrong sops password.
SYNC_ADDR=$(atuin config get sync_address 2>/dev/null | tail -1)
case "$SYNC_ADDR" in
http://* | https://*) : ;;
*) die 2 "no sync_address in config.toml — rebuild this host (modules/shell/atuin.nix sets it)" ;;
esac
case "$SYNC_ADDR" in
*api.atuin.sh*) die 2 "sync_address is the public api.atuin.sh — this host's config.toml did not come from the flake" ;;
esac

# --- credentials -----------------------------------------------------------
REPO="${NIXCONFIG:-}"
if [ -z "$REPO" ]; then
  for c in "$HOME/Documents/nixconfig" /srv/data/projects/nixconfig /Volumes/data/projects/nixconfig; do
    [ -f "$c/modules/secrets.yaml" ] && {
      REPO="$c"
      break
    }
  done
fi
from_sops() {
  [ -n "$REPO" ] && command -v sops >/dev/null && [ -f "$REPO/modules/secrets.yaml" ] || return 1
  (cd "$REPO" && sops -d --extract "[\"atuin\"][\"$1\"]" modules/secrets.yaml) 2>/dev/null
}
if [ -z "${ATUIN_PASSWORD:-}" ]; then
  ATUIN_PASSWORD=$(from_sops password) || ATUIN_PASSWORD=""
fi
if [ -z "${ATUIN_KEY:-}" ]; then
  ATUIN_KEY=$(from_sops key) || ATUIN_KEY=""
fi
if [ -z "$ATUIN_PASSWORD" ] || [ -z "$ATUIN_KEY" ]; then
  die 3 "no credentials — export ATUIN_PASSWORD and ATUIN_KEY (the mnemonic), or point NIXCONFIG at a repo sops can decrypt from"
fi
[ "$(printf '%s' "$ATUIN_KEY" | wc -w)" -ge 12 ] || die 3 "ATUIN_KEY is not a mnemonic — that is the base64 key-file form"

export ATUIN_SESSION="${ATUIN_SESSION:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "bootstrap-$$-$RANDOM")}"

# --- 1. login (not 'register': registration is closed server-side) ---------
LOGIN="skipped"
if ! atuin status >/dev/null 2>&1; then
  atuin login -u "${ATUIN_USER:-devji}" -p "$ATUIN_PASSWORD" -k "$ATUIN_KEY" >/dev/null 2>&1 ||
    die 4 "atuin login failed (wrong password, or base64 key passed instead of the mnemonic)"
  LOGIN="done"
fi

# --- 2. seed history that predates atuin, exactly once ---------------------
# atuin import is NOT idempotent: a second 'import bash' doubles the rows
# (measured 1,940 -> 3,880), so the marker is the guard.
SEED="skipped (already seeded)"
if [ "$FORCE_SEED" = 1 ] || [ ! -e "$MARKER" ]; then
  seeded=""
  [ -f "$HOME/.config/nushell/history.sqlite3" ] && {
    atuin import nu-hist-db >/dev/null 2>&1 && seeded="$seeded nu-hist-db"
  }
  [ -s "$HOME/.bash_history" ] && {
    atuin import bash >/dev/null 2>&1 && seeded="$seeded bash"
  }
  touch "$MARKER"
  SEED="done:${seeded:- nothing to import}"
fi

# --- 3. sync, twice: the first pushes, the second proves it converged ------
_items() { sed -n 's/.*Sync complete! \([0-9][0-9]*\) items.*/\1/p' <<<"$1" | tail -1; }
first=$(atuin sync 2>&1) || die 4 "atuin sync failed: $(tail -1 <<<"$first")"
second=$(atuin sync 2>&1) || die 4 "second atuin sync failed: $(tail -1 <<<"$second")"
ITEMS=$(_items "$second")
[ -n "$ITEMS" ] || die 4 "could not read an item count from: $(tail -1 <<<"$second")"

echo "host        $HOST"
echo "atuin       $(atuin --version 2>/dev/null | awk '{print $2}')"
echo "key         $(basename "$(readlink -f "$KEYFILE")") · 60-char base64"
echo "login       $LOGIN"
echo "seed        $SEED"
echo "items       $ITEMS"
if command -v sqlite3 >/dev/null && [ -f "$DATA/history.db" ]; then
  echo "by shell    $(sqlite3 "$DATA/history.db" "select group_concat(shell||' '||n, ' / ') from (select shell, count(*) n from history group by shell)")"
fi

if [ -n "$EXPECT" ] && [ "$ITEMS" != "$EXPECT" ]; then
  die 5 "item count $ITEMS != expected $EXPECT — the fleet has not converged (this host's import or the server is behind)"
fi
echo "verdict     synced"
