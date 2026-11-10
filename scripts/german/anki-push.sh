#!/usr/bin/env bash
# Author -> server, one command: build decks/*.toml over the schema-11 base,
# upload, download again, and print what the server now serves.
#
# Why the base is the .apkg and not the download: an upload replaces the whole
# collection and the server migrates to schema 18 on arrival, so only the
# schema-11 original can be merged into (see docs/service-offload.md).
#
# Usage:
#   scripts/german/anki-push.sh --base /srv/data/german/audio/B1_....apkg \
#     decks/b2.toml decks/b2-schreiben-mock.toml
#
# Everything the run produced stays under $OUT (default /tmp/anki-push) except
# the backup, which lands next to the other collection backups.
set -euo pipefail

SYNC_URL=${SYNC_URL:-http://anki.frieren.lan}
SYNC_USER=${SYNC_USER:-devji}
BACKUP_DIR=${BACKUP_DIR:-/srv/data/german/anki-backups}
OUT=${OUT:-/tmp/anki-push}
if [ -n "${AUTHOR:-}" ]; then
  read -ra author <<<"$AUTHOR"
else
  # The deck compiler ships with the flake; borrowing it keeps this script
  # working on a host that has nothing installed.
  author=(nix run --builders "" .#cli.learn.anki-author --)
fi

base=""
decks=()
while [ $# -gt 0 ]; do
  case $1 in
    --base)
      base=$2
      shift 2
      ;;
    -h | --help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      decks+=("$1")
      shift
      ;;
  esac
done
[ -n "$base" ] || {
  echo "anki-push: --base <schema-11 collection or .apkg> is required" >&2
  exit 2
}
[ ${#decks[@]} -gt 0 ] || {
  echo "anki-push: name at least one deck file" >&2
  exit 2
}

mkdir -p "$OUT"
PASS_FILE=$OUT/pass
trap 'rm -f "$PASS_FILE"' EXIT
. "$(dirname "$0")/../task/lib/paths.sh"
secret_get '["anki-sync"]["password"]' >"$PASS_FILE"
chmod 600 "$PASS_FILE"

# A v11 request is a JSON header plus a zstd body; the header is what the
# server's extractor wants, and hostKey is the only call that sends no hkey.
header() {
  printf '{"v":11,"k":"%s","c":"nixconfig-anki-push","s":"anki-push"}' "$1"
}
call() {
  local method=$1 body=$2 out=$3 key=${4:-}
  local zst=$OUT/body.zst
  if [ -n "$body" ]; then
    zstd -q -f -c "$body" >"$zst"
  else
    printf '{}' | zstd -q -c >"$zst"
  fi
  curl -sS --max-time 600 -o "$out" -w '%{http_code}' -X POST "$SYNC_URL/sync/$method" \
    -H "anki-sync: $(header "$key")" -H 'Content-Type: application/octet-stream' \
    --data-binary @"$zst"
}

python3 - "$PASS_FILE" "$SYNC_USER" >"$OUT/hk.json" <<'PY'
import json, sys
password = open(sys.argv[1]).read().strip()
print(json.dumps({"u": sys.argv[2], "p": password}), end="")
PY
if [ "$(call hostKey "$OUT/hk.json" "$OUT/hk.out")" != 200 ]; then
  echo "anki-push: hostKey refused the sops credential" >&2
  exit 1
fi
key=$(zstd -dq -c "$OUT/hk.out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["key"])')

# Back up what is being replaced before replacing it.
mkdir -p "$BACKUP_DIR"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
[ "$(call download "" "$OUT/before.zst" "$key")" = 200 ]
zstd -dq -f -c "$OUT/before.zst" >"$BACKUP_DIR/collection-$stamp-v18.anki2"
echo "backup  $BACKUP_DIR/collection-$stamp-v18.anki2"

# A rebuild starts from the schema-11 base, so it carries no review history:
# uploading over a collection that has been reviewed would silently drop it.
reviewed=$(sqlite3 "$BACKUP_DIR/collection-$stamp-v18.anki2" 'select count(*) from cards where type != 0')
if [ "$reviewed" != 0 ] && [ "${FORCE:-0}" != 1 ]; then
  echo "anki-push: the served collection has $reviewed reviewed cards; this upload would" >&2
  echo "           replace them with unseen copies. Carry the review history over by hand," >&2
  echo "           or set FORCE=1 to accept the loss. Backup above." >&2
  exit 3
fi

work=$base
for deck in "${decks[@]}"; do
  target=$OUT/$(basename "$deck" .toml).anki2
  "${author[@]}" build --deck "$deck" --base "$work" --out "$target"
  work=$target
done

[ "$(call upload "$work" "$OUT/upload.out" "$key")" = 200 ]
[ "$(zstd -dq -c "$OUT/upload.out")" = "OK" ] || {
  echo "anki-push: upload answered $(zstd -dq -c "$OUT/upload.out")" >&2
  exit 1
}

[ "$(call download "" "$OUT/after.zst" "$key")" = 200 ]
zstd -dq -f -c "$OUT/after.zst" >"$OUT/after.anki2"
# The served copy is schema 18, whose deck names use Anki's `unicase`
# collation: ORDER BY on them, or counting the table in a subquery, makes plain
# sqlite3 fail. Selecting the columns as they are does not.
sqlite3 "$OUT/after.anki2" <<'SQL'
select 'served  ' || count(*) || ' notes' from notes;
select '        ' || count(*) || ' cards' from cards;
select '        ' || count(*) || ' cards carry a req- tag' from notes where tags like '%req-%';
select '        ' || replace(name, char(31), '::') from decks;
SQL
