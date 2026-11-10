#!/usr/bin/env bash
# InstaBox machines over the HTTP API and plain ssh — curl, jq and ssh, no
# provider CLI and nothing it installs. The key is the one sops already holds
# (`INSTABOX.API.KEY` in apikeys.yaml); `INSTABOX_API_KEY` overrides it for a
# host without the keys. Procedure and measured traps: .agents/skills/instabox.
#
# Exit: 0 ok · 1 refused (bad key, unknown machine, API error) · 2 usage ·
# for `exec`/`run`, the command's own status.
set -euo pipefail

API="${INSTABOX_API_URL:-https://api.instabox.sh}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# A store copy has no .git; the script's own location then walks up two levels.
# Two assignments rather than one `||`: a compound command inside `$( )`
# concatenates both answers into one unopenable path.
root="$(git -C "$here" rev-parse --show-toplevel 2>/dev/null)" || true
[ -n "$root" ] || root="$(cd "$here/../.." && pwd)"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig-instabox"

die() {
  echo "instabox: $*" >&2
  exit 1
}
usage() {
  cat >&2 <<'EOF'
usage: instabox.sh <command> [args]

  ls                      machines in this key's workspace
  get  <name|id>          one machine's full record
  token <name|id>         print the machine's ssh line (minted, cached, 7 days)
  forward <name|id> <port> [remote]  foreground loopback forward (no remote cmd)
  ssh  <name|id> [-- cmd] interactive shell, or one command
  run  <name|id> -- cmd   one command over ssh
  exec <name|id> -- cmd   one command through the API (no ssh, no token)
  start|stop|suspend|resume|wake <name|id>
  ports <name|id>         published ports
EOF
  exit 2
}

# Sets KEY in this shell rather than echoing it: a `die` inside `$( )` only
# ends the subshell, and the caller then sends an empty key to the API.
KEY=""
. "${BASH_SOURCE[0]%/*}/lib/paths.sh"

load_key() {
  [ -n "$KEY" ] && return
  if [ -n "${INSTABOX_API_KEY:-}" ]; then
    KEY="$INSTABOX_API_KEY"
    return
  fi
  KEY="$(sops -d --output-type json "$(apikeys_file)" 2>/dev/null |
    jq -r '.INSTABOX.API.KEY // empty')" || die "cannot decrypt apikeys.yaml (no sops keys here?)"
  [ -n "$KEY" ] || die "no INSTABOX.API.KEY in apikeys.yaml"
}

api() {
  local method="$1" path="$2" body="${3:-}" out
  load_key
  if [ -n "$body" ]; then
    out="$(curl -sS --max-time 90 --retry 2 -X "$method" \
      -H "X-API-Key: $KEY" -H 'Content-Type: application/json' \
      --data-binary "$body" "$API$path")" || die "network: $API$path unreachable"
  else
    out="$(curl -sS --max-time 90 --retry 2 -X "$method" \
      -H "X-API-Key: $KEY" "$API$path")" || die "network: $API$path unreachable"
  fi
  if jq -e '.error.code' >/dev/null 2>&1 <<<"$out"; then
    die "$(jq -r '"api " + .error.code + ": " + (.error.message // "")' <<<"$out")"
  fi
  printf '%s' "$out"
}

# A name is what a person remembers; an id is what never collides. Both are
# accepted, because a token line and an API reply only ever speak ids.
resolve() {
  local want="${1:-}" json id
  [ -n "$want" ] || usage
  case "$want" in
    m_*) printf '%s' "$want"; return ;;
  esac
  json="$(api GET /v1/machines)"
  id="$(jq -r --arg n "$want" '[.machines[]? | select(.name == $n) | .id][0] // empty' <<<"$json")"
  [ -n "$id" ] || die "no machine named '$want' in this workspace"
  printf '%s' "$id"
}

# The ssh line is `ssh [-p PORT] <token>@<host>`: the token *is* the login, so
# there is no key to place and no config block to maintain. It is minted once
# and reused until two minutes before it expires, so a shell command costs one
# API call a week, not one a connection.
ssh_line() {
  local id="$1" file expires
  mkdir -p "$cache"
  chmod 700 "$cache"
  file="$cache/$id.ssh.json"
  if [ -s "$file" ]; then
    expires="$(jq -r --argjson now "$(date +%s)" \
      'select(((.expiresAt // "1970-01-01T00:00:00Z") | fromdateiso8601) > ($now + 120)) | .command' \
      <"$file" 2>/dev/null || true)"
    if [ -n "$expires" ]; then
      printf '%s' "$expires"
      return
    fi
  fi
  api POST "/v1/machines/$id/ssh-tokens" '{"name":"fleet-agent","ttlSeconds":604800}' >"$file"
  chmod 600 "$file"
  jq -r '.command' <"$file"
}

split_line() { # "ssh -p 2222 token@host" -> PORT HOSTARG
  local -a parts
  local i=1
  PORT=22
  HOSTARG=""
  read -ra parts <<<"$1"
  while [ "$i" -lt "${#parts[@]}" ]; do
    case "${parts[$i]}" in
      -p)
        PORT="${parts[$((i + 1))]}"
        i=$((i + 2))
        ;;
      *)
        HOSTARG="${parts[$i]}"
        i=$((i + 1))
        ;;
    esac
  done
  [ -n "$HOSTARG" ] || die "unreadable ssh line"
}

# The gateway terminates ssh, so its host key is what a first connection asks
# about; `accept-new` pins it once into a cache known_hosts instead of a prompt
# that would hang an unattended run.
ssh_on() {
  local id="$1"
  shift
  local line
  line="$(ssh_line "$id")"
  split_line "$line"
  exec ssh -p "$PORT" \
    -o StrictHostKeyChecking=accept-new \
    -o "UserKnownHostsFile=$cache/known_hosts" \
    -o ConnectTimeout=25 \
    -o ServerAliveInterval=30 \
    "$HOSTARG" "$@"
}

cmd="${1:-}"
[ $# -gt 0 ] && shift
case "$cmd" in
  ls | list)
    api GET /v1/machines | jq -r '
      (["NAME", "STATE", "CPU", "MEM", "DISK", "AUTO-SUSPEND", "ID"] | @tsv),
      (.machines[] | [
        .name, .state, (.spec.vcpus | tostring), ((.spec.memMiB / 1024 | floor) | tostring) + "G",
        (.spec.persistentDiskGiB | tostring) + "G",
        ((.autoSuspendAfterSeconds // 0) / 60 | floor | tostring) + "m", .id
      ] | @tsv)' | awk -F'\t' '{printf "%-16s %-10s %-4s %-5s %-5s %-7s %s\n", $1, $2, $3, $4, $5, $6, $7}'
    ;;
  get)
    api GET "/v1/machines/$(resolve "${1:-}")" | jq .
    ;;
  token)
    id="$(resolve "${1:-}")"
    printf '%s\n' "$(ssh_line "$id")"
    ;;
  ssh)
    id="$(resolve "${1:-}")"
    shift || true
    [ "${1:-}" = "--" ] && shift
    ssh_on "$id" "$@"
    ;;
  forward)
    # A loopback forward and nothing else: the only reachability a service on
    # this machine has, since nothing here publishes a port.
    id="$(resolve "${1:-}")"
    local_port="${2:-}"
    remote_port="${3:-$local_port}"
    [ -n "$local_port" ] || usage
    line="$(ssh_line "$id")"
    split_line "$line"
    exec ssh -N \
      -p "$PORT" \
      -L "127.0.0.1:$local_port:127.0.0.1:$remote_port" \
      -o ExitOnForwardFailure=yes \
      -o StrictHostKeyChecking=accept-new \
      -o "UserKnownHostsFile=$cache/known_hosts" \
      -o ConnectTimeout=25 \
      -o ServerAliveInterval=30 \
      "$HOSTARG"
    ;;
  run)
    id="$(resolve "${1:-}")"
    shift || true
    [ "${1:-}" = "--" ] && shift
    [ $# -gt 0 ] || usage
    ssh_on "$id" "$@"
    ;;
  exec)
    id="$(resolve "${1:-}")"
    shift || true
    [ "${1:-}" = "--" ] && shift
    [ $# -gt 0 ] || usage
    body="$(jq -nc --arg c "$*" '{cmd: $c}')"
    out="$(api POST "/v1/machines/$id/exec" "$body")"
    # Empty stderr is the common case: printing it unconditionally is a blank
    # line before every answer, which reads as a broken command in a script.
    err="$(jq -r '.stderr // ""' <<<"$out")"
    [ -n "$err" ] && printf '%s\n' "$err" >&2
    jq -r '.stdout // ""' <<<"$out"
    exit "$(jq -r '.exitCode // 0' <<<"$out")"
    ;;
  start | stop | suspend | resume | wake)
    id="$(resolve "${1:-}")"
    out="$(api POST "/v1/machines/$id/$cmd" '{}')"
    printf '%s: %s requested (%s)\n' "$cmd" "$id" \
      "$(jq -r '.operationId // .id // "no operation id"' <<<"$out")"
    printf 'watch with: instabox.sh get %s | jq -r .state\n' "$id"
    ;;
  ports)
    api GET "/v1/machines/$(resolve "${1:-}")/ports" | jq .
    ;;
  *)
    usage
    ;;
esac
