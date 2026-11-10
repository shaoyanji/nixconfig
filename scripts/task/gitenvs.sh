#!/usr/bin/env bash
# git.envs.net (Forgejo) over its REST API: the verbs `gh` would give you, with
# the token read from sops instead of a browser login. Only forge metadata moves
# here; code still travels over git, so `create` prints the remote to add.
#
# Called by `task envs:git:*`. GITENVS_URL overrides the API base.
set -euo pipefail

API="${GITENVS_URL:-https://git.envs.net/api/v1}"

. "${BASH_SOURCE[0]%/*}/lib/paths.sh"

die() {
  printf 'gitenvs: %s\n' "$*" >&2
  exit 1
}

token() {
  secret_get '["gitenvstoken"]' || die "gitenvstoken is unreadable from sops (submodule checked out? age key?)"
}

# The token rides in a header read from stdin, so it never reaches another
# process's argv for `ps` to read.
api() {
  local method=$1 path=$2 body=${3:-}
  local args=(-sS --max-time 30 -X "$method" -H @-)
  if [ -n "$body" ]; then
    args+=(-H 'Content-Type: application/json' --data-raw "$body")
  fi
  printf 'Authorization: token %s\n' "$(token)" | curl "${args[@]}" "$API$path"
}

api_code() {
  local method=$1 path=$2
  printf 'Authorization: token %s\n' "$(token)" \
    | curl -sS --max-time 30 -o /dev/null -w '%{http_code}' -X "$method" -H @- "$API$path"
}

owner() {
  local me
  me=$(api GET /user)
  printf '%s' "$me" | jq -r '.login // empty'
}

message_of() {
  printf '%s' "$1" | jq -r '.message // "unexpected response from the forge"' 2>/dev/null \
    || printf 'unexpected response from the forge'
}

cmd_whoami() {
  local me repos
  me=$(api GET /user)
  [ -n "$(printf '%s' "$me" | jq -r '.login // empty')" ] || die "token rejected: $(message_of "$me")"
  repos=$(api GET '/user/repos?limit=50')
  printf '%s' "$me" | jq -r --arg api "$API" '
    "user    \(.login)
email   \(.email // "-")
admin   \(.is_admin)
api     \($api)"'
  printf 'repos   %s\n' "$(printf '%s' "$repos" | jq 'length')"
}

cmd_repos() {
  local fmt=${1:-text} raw
  raw=$(api GET '/user/repos?limit=50')
  printf '%s' "$raw" | jq -e 'type == "array"' >/dev/null || die "$(message_of "$raw")"
  case "$fmt" in
    json) printf '%s\n' "$raw" | jq '.' ;;
    *)
      printf '%s' "$raw" | jq -r '.[] |
        "\(if .private then "private" else "public " end)  \(.full_name)  \(.updated_at[0:10])  \(.description // "" | .[0:48])"'
      ;;
  esac
}

cmd_create() {
  local name=${1:-} public=${2:-0} desc=${3:-} body out
  [ -n "$name" ] || die "a repository name is required (NAME=...)"
  body=$(jq -n --arg n "$name" --arg d "$desc" --argjson p "$([ "$public" = 1 ] && printf false || printf true)" \
    '{name: $n, private: $p, auto_init: true} + (if $d == "" then {} else {description: $d} end)')
  out=$(api POST /user/repos "$body")
  printf '%s' "$out" | jq -e '.full_name' >/dev/null || die "$(message_of "$out")"
  printf '%s' "$out" | jq -r '"created  \(.html_url)
private  \(.private)
ssh      \(.ssh_url)"'
}

cmd_show() {
  local name=${1:-} o out
  [ -n "$name" ] || die "a repository name is required (NAME=...)"
  o=$(owner)
  out=$(api GET "/repos/$o/$name")
  printf '%s' "$out" | jq -e '.full_name' >/dev/null || die "$(message_of "$out")"
  printf '%s' "$out" | jq -r '
    "repo     \(.full_name)\(if .private then "  (private)" else "" end)
branch   \(.default_branch)
updated  \(.updated_at[0:10])   size \(.size) KiB   issues \(.open_issues_count)
https    \(.clone_url)
ssh      \(.ssh_url)"'
}

cmd_delete() {
  local name=${1:-} confirm=${2:-} o code
  [ -n "$name" ] || die "a repository name is required (NAME=...)"
  o=$(owner)
  [ "$confirm" = "$name" ] || die "refusing to delete $o/$name; repeat it as CONFIRM=$name to mean it"
  code=$(api_code DELETE "/repos/$o/$name")
  case "$code" in
    204) printf 'deleted  %s/%s\n' "$o" "$name" ;;
    404) die "no repository $o/$name" ;;
    *) die "the forge refused the delete (HTTP $code)" ;;
  esac
}

cmd_api() {
  local method=${1:-GET} path=${2:-} body=${3:-} out
  [ -n "$path" ] || die "usage: gitenvs.sh api METHOD PATH [JSON]"
  out=$(api "$method" "$path" "$body")
  printf '%s' "$out" | jq '.' 2>/dev/null || printf '%s\n' "$out"
}

case "${1:-}" in
  whoami) cmd_whoami ;;
  repos)
    shift
    cmd_repos "${1:-text}"
    ;;
  create)
    shift
    cmd_create "${1:-}" "${2:-0}" "${3:-}"
    ;;
  show)
    shift
    cmd_show "${1:-}"
    ;;
  delete)
    shift
    cmd_delete "${1:-}" "${2:-}"
    ;;
  api)
    shift
    cmd_api "${1:-GET}" "${2:-}" "${3:-}"
    ;;
  *)
    sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
