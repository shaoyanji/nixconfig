#!/usr/bin/env bash
# alwaysdata.sh — one Alwaysdata API call with the token from sops.
#
# The token is `alwaysdatatoken` in `modules/secrets.yaml` and is read at call
# time, never exported to a file. Alwaysdata takes it as the basic-auth *user*
# with an empty password (`curl --user APIKEY:`), which is why there is no header
# to build. `ALWAYSDATA_ACCOUNT` selects a linked account when the token spans
# several: the API wants it inside the user field, not as a separate argument.
#
#   alwaysdata.sh [METHOD] [PATH] [JQ]
#
# `GET /v1/account/` is the default and the cheapest way to prove the token
# works. A write passes `BODY` (JSON) or `BODY=-` for stdin:
#
#   BODY='{"addresses":[{"ip":"","type":"ipv4"}]}' alwaysdata.sh POST /v1/site/ \
#     '.[] | {id, name}'
#
# The response is always filtered through jq, so a task can ask for a table
# (`.[] | [.name, .type] | @tsv`) instead of a document. Rate limits are 250 rpm
# for GET and 50 rpm for writes; this script makes one call, so a loop owns its
# own pace.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
method=${1:-GET}
path=${2:-/v1/account/}
filter=${3:-.}

method=$(printf '%s' "$method" | tr '[:lower:]' '[:upper:]')
case "$path" in
  /*) ;;
  *) path=/$path ;;
esac

for cmd in sops jq curl; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "alwaysdata: $cmd is required" >&2
    exit 2
  }
done

token=$(sops -d --extract '["alwaysdatatoken"]' "$repo/modules/secrets.yaml" 2>/dev/null) || {
  echo "alwaysdata: cannot decrypt alwaysdatatoken from modules/secrets.yaml (age key?)" >&2
  exit 2
}
[ -n "$token" ] || {
  echo "alwaysdata: alwaysdatatoken is empty in modules/secrets.yaml" >&2
  exit 2
}

user=$token
if [ -n "${ALWAYSDATA_ACCOUNT:-}" ]; then
  user="$token account=$ALWAYSDATA_ACCOUNT"
fi

args=(--silent --show-error --fail-with-body --max-time 30 --basic --user "$user:")
args+=(--request "$method" --header 'Accept: application/json')
if [ -n "${BODY:-}" ]; then
  body=$BODY
  [ "$body" = "-" ] && body=$(cat)
  args+=(--header 'content-type: application/json' --data "$body")
fi

curl "${args[@]}" "https://api.alwaysdata.com$path" | jq -r "$filter"
