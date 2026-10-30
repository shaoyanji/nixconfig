#!/usr/bin/env bash
# neocities-push.sh — publish a static directory to Neocities.
#
# WHY THIS EXISTS: the deploy path for dragoncourt.neocities.org must prove what it
# published. The API's upload message says "success" whether or not the bytes landed as
# intended, so this compares SHA-1 hashes first (upload_hash), sends only the files that
# differ, then downloads each uploaded path back and compares it byte for byte. A failed
# round trip is a failed deploy, exit 1.
#
# The credential is NEOCITIES.API.KEY in the sops secrets plane; nothing is exported to
# the environment beyond the curl invocation.
#
# Usage: neocities-push.sh [site-dir] [--preflight] [--dry-run] [--prune]
#   --preflight  only lint the site: links, required files, feed XML. Uploads nothing.
#   --dry-run    report which files would be uploaded, then stop.
#   --prune      also delete remote files that no longer exist locally (destructive,
#                lists them first; never implied).
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
site="$repo/projects/neocities-dragoncourt/site"
secrets="$repo/modules/secrets/apikeys.yaml"
api="https://neocities.org/api"

preflight_only=0
dry_run=0
prune=0

usage() {
  sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

die() {
  echo "neocities-push: $*" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --preflight) preflight_only=1 ;;
    --dry-run) dry_run=1 ;;
    --prune) prune=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      die "unknown flag '$1' (try --help)"
      ;;
    *)
      site="$1"
      ;;
  esac
  shift
done

[ -d "$site" ] || die "site directory '$site' does not exist"
site="$(cd "$site" && pwd)"
[ -f "$site/index.html" ] || die "$site/index.html is missing — Neocities needs a root index"

# ---- preflight ---------------------------------------------------------------

preflight() {
  # The rules belong to the project repository: CI runs the same script there, so the
  # deploy path and the gate can never disagree about what a valid site is.
  local linter="$site/../scripts/lint.py"
  [ -f "$linter" ] || die "no scripts/lint.py beside the site — the project repository owns the rules"
  python3 "$linter" "$site"
}

echo "site: $site"
preflight
[ "$preflight_only" = "1" ] && exit 0

# ---- credentials -------------------------------------------------------------

[ -f "$secrets" ] || die "$secrets missing (is the modules/secrets submodule checked out?)"
key="$(sops -d --extract '["NEOCITIES"]["API"]["KEY"]' "$secrets")"
[ -n "$key" ] || die "NEOCITIES.API.KEY is empty in $secrets"

if command -v sha1sum >/dev/null; then
  sha1() { sha1sum "$1" | cut -d' ' -f1; }
else
  sha1() { shasum -a 1 "$1" | cut -d' ' -f1; }
fi

curl_api() { curl -sS -H "Authorization: Bearer $key" "$@"; }

# ---- what changed ------------------------------------------------------------

mapfile -t files < <(cd "$site" && find . -type f -print | sed 's|^\./||' | sort)
[ "${#files[@]}" -gt 0 ] || die "nothing to publish in $site"

hash_args=()
for rel in "${files[@]}"; do
  hash_args+=(--data-urlencode "${rel}=$(sha1 "$site/$rel")")
done

hash_response="$(curl_api "${hash_args[@]}" "$api/upload_hash")"
if [ "$(echo "$hash_response" | jq -r '.result')" != "success" ]; then
  echo "$hash_response" >&2
  die "upload_hash failed"
fi

changed=()
for rel in "${files[@]}"; do
  if [ "$(echo "$hash_response" | jq -r --arg p "$rel" '.files[$p] // false')" != "true" ]; then
    changed+=("$rel")
  fi
done

echo "remote: $(( ${#files[@]} - ${#changed[@]} )) file(s) already match, ${#changed[@]} changed"

if [ "${#changed[@]}" -eq 0 ]; then
  echo "nothing to upload"
else
  printf '  %s\n' "${changed[@]}"
fi

if [ "$dry_run" = "1" ]; then
  echo "dry run: nothing uploaded"
  exit 0
fi

# ---- upload ------------------------------------------------------------------

if [ "${#changed[@]}" -gt 0 ]; then
  upload_args=()
  for rel in "${changed[@]}"; do
    upload_args+=(-F "${rel}=@${site}/${rel}")
  done
  upload_response="$(curl_api "${upload_args[@]}" "$api/upload")"
  if [ "$(echo "$upload_response" | jq -r '.result')" != "success" ]; then
    echo "$upload_response" >&2
    die "upload failed"
  fi
  echo "uploaded: ${#changed[@]} file(s)"
fi

# ---- verify: the served bytes are the source bytes ---------------------------

failed=0
for rel in "${changed[@]}"; do
  tmp="$(mktemp)"
  if ! curl_api -o "$tmp" --get --data-urlencode "path=$rel" "$api/download"; then
    echo "verify: $rel — download failed" >&2
    failed=1
  elif [ "$(sha1 "$tmp")" != "$(sha1 "$site/$rel")" ]; then
    echo "verify: $rel — served bytes differ from local" >&2
    failed=1
  fi
  rm -f "$tmp"
done
[ "$failed" = "0" ] || die "verification failed: the upload did not land as sent"
echo "verified: every uploaded path round-trips byte for byte"

# ---- prune (opt-in, destructive) --------------------------------------------

if [ "$prune" = "1" ]; then
  list_response="$(curl_api "$api/list")"
  if [ "$(echo "$list_response" | jq -r '.result')" != "success" ]; then
    echo "$list_response" >&2
    die "list failed"
  fi
  stale=()
  while IFS= read -r remote; do
    [ -n "$remote" ] || continue
    keep=0
    for rel in "${files[@]}"; do
      if [ "$rel" = "$remote" ]; then
        keep=1
        break
      fi
    done
    [ "$keep" = "1" ] || stale+=("$remote")
  done < <(echo "$list_response" | jq -r '.files[] | select(.is_directory == false) | .path')

  if [ "${#stale[@]}" -eq 0 ]; then
    echo "prune: nothing stale"
  else
    echo "prune: deleting ${#stale[@]} remote file(s) with no local counterpart:"
    printf '  %s\n' "${stale[@]}"
    delete_args=()
    for rel in "${stale[@]}"; do
      delete_args+=(--data-urlencode "filenames[]=$rel")
    done
    delete_response="$(curl_api "${delete_args[@]}" "$api/delete")"
    if [ "$(echo "$delete_response" | jq -r '.result')" != "success" ]; then
      echo "$delete_response" >&2
      die "delete failed"
    fi
    echo "prune: done"
  fi
fi

# ---- report ------------------------------------------------------------------

info="$(curl_api "$api/info")"
echo "live: $(echo "$info" | jq -r '.info.sitename').neocities.org"
echo "last_updated: $(echo "$info" | jq -r '.info.last_updated // "unknown"')"
