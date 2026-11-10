#!/usr/bin/env bash
# cloudinary.sh — the one credential reader and one signing path for image assets.
#
# WHY THIS EXISTS: an image belongs at a delivery URL, not as a blob in the repo
# next to the page that shows it. Cloudinary puts the resize in the URL, so one
# upload serves the 1200x630 card, the 320px thumbnail and the retina hero, and
# a consumer picks its own crop without a second upload. The credential lives in
# sops at CLOUDINARY.{NAME,API.KEY,API.SECRET}, so no interactive login is
# involved and an unattended run has the same rights as a shell.
#
# Usage:
#   cloudinary.sh upload FILE [--folder F] [--public-id ID]   -> prints secure_url
#   cloudinary.sh url PUBLIC_ID [--transform T]               -> prints delivery URL
#
# The signature is sha1 of the signed-parameter string in alphabetical key order
# with the API secret appended. `file` and `api_key` are never part of it.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "${BASH_SOURCE[0]%/*}/lib/paths.sh"
secrets=$(apikeys_file)
if [ ! -f "$secrets" ]; then
  echo "cloudinary.sh: $secrets missing (is the modules/secrets submodule checked out?)" >&2
  exit 1
fi

# One decrypt, three fields: three separate sops calls is three age ops per image.
# This sops has no `-o json` for a yaml input, so ask for the output type and fall
# back to yq rather than depending on a flag that answers "unknown".
creds=$(sops -d --output-type json "$secrets" 2>/dev/null | jq -c '.CLOUDINARY // empty' 2>/dev/null || true)
if [ -z "${creds:-}" ]; then
  creds=$(sops -d "$secrets" 2>/dev/null | yq -p yaml -o json 2>/dev/null | jq -c '.CLOUDINARY // empty')
fi
name=$(printf '%s' "$creds" | jq -r '.NAME // empty')
key=$(printf '%s' "$creds" | jq -r '.API.KEY // empty')
secret=$(printf '%s' "$creds" | jq -r '.API.SECRET // empty')
if [ -z "$name" ] || [ -z "$key" ] || [ -z "$secret" ]; then
  echo "cloudinary.sh: CLOUDINARY.NAME, CLOUDINARY.API.KEY and CLOUDINARY.API.SECRET are all required" >&2
  exit 1
fi

cmd=${1:?usage: cloudinary.sh upload FILE|url PUBLIC_ID}
shift

case "$cmd" in
  upload)
    file=${1:?upload needs a file}
    shift
    folder=""; public_id=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --folder) folder=${2:?--folder needs a value}; shift 2 ;;
        --public-id) public_id=${2:?--public-id needs a value}; shift 2 ;;
        *) echo "cloudinary.sh: unknown argument $1" >&2; exit 2 ;;
      esac
    done
    [ -f "$file" ] || { echo "cloudinary.sh: no such file: $file" >&2; exit 1; }

    ts=$(date +%s)
    # Cloudinary signs `folder` OR `public_id`, never both: with a folder in the
    # request the public_id is excluded from the string to sign, so signing both
    # answers "Invalid Signature" and names the string it expected. A caller that
    # wants a nested id passes it whole and no folder is sent.
    args=(-sS -X POST "https://api.cloudinary.com/v1_1/$name/image/upload"
      -F "file=@$file" -F "api_key=$key" -F "timestamp=$ts")
    if [ -n "$public_id" ]; then
      [ -n "$folder" ] && public_id="$folder/$public_id"
      sig=$(printf '%s' "public_id=$public_id&timestamp=$ts$secret" | sha1sum | cut -d' ' -f1)
      args+=(-F "public_id=$public_id" -F "signature=$sig")
    elif [ -n "$folder" ]; then
      sig=$(printf '%s' "folder=$folder&timestamp=$ts$secret" | sha1sum | cut -d' ' -f1)
      args+=(-F "folder=$folder" -F "signature=$sig")
    else
      sig=$(printf '%s' "timestamp=$ts$secret" | sha1sum | cut -d' ' -f1)
      args+=(-F "signature=$sig")
    fi

    out=$(curl "${args[@]}")
    err=$(printf '%s' "$out" | jq -r '.error.message // empty' 2>/dev/null || true)
    if [ -n "$err" ]; then
      echo "cloudinary.sh: upload refused: $err" >&2
      exit 1
    fi
    url=$(printf '%s' "$out" | jq -r '.secure_url // empty')
    if [ -z "$url" ]; then
      echo "cloudinary.sh: no secure_url in the response" >&2
      printf '%s\n' "$out" | head -c 400 >&2
      exit 1
    fi
    printf '%s\n' "$url"
    ;;

  url)
    id=${1:?url needs a public id}
    shift
    transform="f_auto,q_auto"
    while [ $# -gt 0 ]; do
      case "$1" in
        --transform) transform=${2:?--transform needs a value}; shift 2 ;;
        *) echo "cloudinary.sh: unknown argument $1" >&2; exit 2 ;;
      esac
    done
    printf 'https://res.cloudinary.com/%s/image/upload/%s/%s\n' "$name" "$transform" "$id"
    ;;

  *)
    echo "cloudinary.sh: unknown command $cmd (upload|url)" >&2
    exit 2
    ;;
esac
