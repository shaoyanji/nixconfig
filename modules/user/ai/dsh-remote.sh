#!/usr/bin/env bash
# dsh-remote — open the DeepSeek Harness that runs on a worker host.
#
# The harness is a SERVICE on the worker (systemd unit `dsh-web`) bound to
# loopback there, and the worker publishes it through its TLS ingress at
# `/deepseek/`. This client opens the browser; it does not proxy anything, so
# the tab survives this command, the URL is bookmarkable, and the worker's CPU,
# disk and model access are what the UI is talking to.
#
# The ingress is gated by dsh's launch token. The unit prints one signed-in URL
# per start to its journal; that is what this script reads over ssh (never a
# password, never a copy of the token on disk).
set -euo pipefail

HOST="${DSH_HOST:-delphi.bountystash.com}"
SERVICE="${DSH_SERVICE:-dsh-web}"
SYNC_AUTH="${DSH_SYNC_AUTH:-auto}"
OPEN_BROWSER="${DSH_OPEN_BROWSER:-1}"
PORT="${DSH_PORT:-3080}"
ACTION=run

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=20)

die() {
  printf 'dsh-remote: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
dsh-remote — open the DeepSeek Harness that runs on a remote worker

  dsh-remote                 open the harness Web UI in this browser
  dsh-remote --url           print the signed-in URL (paste it on another device)
  dsh-remote --status        is the worker's harness running; exit 1 if not
  dsh-remote --restart       restart it on the worker, then open a fresh URL
  dsh-remote --stop          stop it on the worker
  dsh-remote --log           follow its journal on the worker
  dsh-remote --sync-auth     re-import this client's DeepSeek credential
  dsh-remote --no-sync-auth  never import it; sign in through the Web UI instead
  dsh-remote --no-browser    print the URL instead of opening a browser
  dsh-remote --host <host>   another worker (default delphi.bountystash.com)

The harness runs on the worker and binds loopback there; the worker serves it at
https://<host>/deepseek/ behind its own TLS vhost. Nothing is tunneled from this
machine, so closing this command does not close the tab. The first visit to a
browser profile exchanges the printed token for a 30-day cookie, after which the
bare https://<host>/deepseek/ works on its own.

Env: DSH_HOST DSH_SERVICE DSH_PORT DSH_SYNC_AUTH DSH_OPEN_BROWSER DSH_TIMEOUT
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --host)
      [ $# -ge 2 ] || die "$1 needs a host"
      HOST="$2"
      shift 2
      ;;
    --url) ACTION=url; shift ;;
    --status) ACTION=status; shift ;;
    --stop) ACTION=stop; shift ;;
    --restart) ACTION=restart; shift ;;
    --log) ACTION=log; shift ;;
    --sync-auth) SYNC_AUTH=always; shift ;;
    --no-sync-auth) SYNC_AUTH=never; shift ;;
    --no-browser) OPEN_BROWSER=0; shift ;;
    -h | --help) usage; exit 0 ;;
    *)
      printf 'dsh-remote: unknown argument %s (try --help)\n' "$1" >&2
      exit 2
      ;;
  esac
done

case "$SERVICE" in
  "" | *[!a-zA-Z0-9@._-]*) die "unsupported unit name: $SERVICE" ;;
esac

# Every remote call is a script on stdin (`bash -ls -- args`), so quoting a
# value only has to survive ssh's own argument joining, not a second shell.
remote() {
  ssh "${SSH_OPTS[@]}" "$HOST" bash -ls -- "$@"
}

require_host() {
  local err
  if ! err=$(ssh "${SSH_OPTS[@]}" "$HOST" true 2>&1); then
    printf 'dsh-remote: cannot reach %s non-interactively.\n%s\n' "$HOST" "$err" >&2
    die "accept its host key once with: ssh $HOST true"
  fi
}

# systemd on the worker needs root. delphi has passwordless sudo; anywhere else
# the failure is reported with the command to run by hand rather than a prompt.
unit_cmd() {
  local verb=$1 out
  # shellcheck disable=SC2029 # the unit name is validated above and expanded here on purpose
  if ! out=$(ssh "${SSH_OPTS[@]}" "$HOST" "sudo -n systemctl $verb '$SERVICE'" 2>&1); then
    printf 'dsh-remote: could not %s %s on %s.\n%s\n' "$verb" "$SERVICE" "$HOST" "$out" >&2
    return 1
  fi
}

service_state() {
  remote "$SERVICE" <<'REMOTE' 2>/dev/null | sed -n 's/^DSHSTATE://p' | tail -1
state=$(systemctl is-active "$1" 2>/dev/null || true)
printf 'DSHSTATE:%s\n' "${state:-unknown}"
REMOTE
}

# The harness prints exactly one signed-in URL per start; the last one in the
# journal is the live token. A stale line is caught by probing it.
read_url() {
  remote "$SERVICE" <<'REMOTE' 2>/dev/null | sed -n 's/^DSHURL://p' | tail -1
journalctl -u "$1" -o cat --no-pager 2>/dev/null |
  sed -n 's|^dsh web: \(https\?://[^[:space:]]*\)$|\1|p' | tail -1 | sed 's/^/DSHURL:/'
REMOTE
}

clean_url() {
  printf '%s' "${1%%\?*}"
}

# Prove the ingress from HERE, with a fresh cookie jar: DNS, TLS, the proxy
# prefix, the launch token and the harness all have to work for this to pass.
PROBE_CODE=none
probe_url() {
  local url=$1 dir code
  dir=$(mktemp -d)
  code=$(curl -sS -L -m "${DSH_TIMEOUT:-20}" -c "$dir/jar" -b "$dir/jar" \
    -o "$dir/page" -w '%{http_code}' "$url" 2>/dev/null || true)
  PROBE_CODE="${code:-none}"
  if [ "$code" = 200 ] && grep -qs 'DeepSeek Harness' "$dir/page"; then
    rm -rf "$dir"
    return 0
  fi
  rm -rf "$dir"
  return 1
}

# A restart mints a new token, so "the URL changed" is how we know the line we
# read belongs to the process that is running now.
fresh_url() {
  local old=$1 url
  for _ in $(seq 1 60); do
    url=$(read_url)
    if [ -n "$url" ] && [ "$url" != "$old" ]; then
      printf '%s' "$url"
      return 0
    fi
    sleep 1
  done
  return 1
}

worker_root() {
  remote <<'REMOTE' 2>/dev/null | sed -n 's/^DSHROOT://p' | tail -1
printf 'DSHROOT:%s\n' "${DSH_HOME:-$HOME/.dsh}"
REMOTE
}

# Credentials travel inside the ssh channel, never on a command line, and the
# worker's own account is not overwritten with this client's: a worker that is
# already signed in wins unless the operator asks for the import.
imported=0
sync_auth() {
  local root remote_creds local_creds signed
  [ "$SYNC_AUTH" = never ] && return 0
  local_creds="${DSH_HOME:-$HOME/.dsh}/.credentials.yaml"
  [ -r "$local_creds" ] || return 0
  grep -qs 'deepseek-account-platform/default' "$local_creds" || return 0

  root=$(worker_root)
  [ -n "$root" ] || return 0
  remote_creds="$root/.credentials.yaml"

  if [ "$SYNC_AUTH" != always ]; then
    signed=$(remote "$remote_creds" <<'REMOTE' 2>/dev/null || true
if grep -qs 'deepseek-account-platform/default' "$1"; then printf 'SIGNED\n'; else printf 'UNSIGNED\n'; fi
REMOTE
    )
    [ "$(printf '%s\n' "$signed" | tail -1)" = SIGNED ] && return 0
  fi

  umask 077
  # shellcheck disable=SC2029 # these paths are expanded locally on purpose
  if ! ssh "${SSH_OPTS[@]}" "$HOST" "umask 077; mkdir -p '$root'; if [ -s '$remote_creds' ]; then cp -p '$remote_creds' '$remote_creds.bak'; fi; cat > '$remote_creds.tmp'" <"$local_creds"; then
    printf 'dsh-remote: could not import the credential; sign in through the Web UI instead\n' >&2
    return 0
  fi
  # shellcheck disable=SC2029
  ssh "${SSH_OPTS[@]}" "$HOST" "chmod 600 '$remote_creds.tmp' && mv '$remote_creds.tmp' '$remote_creds'" ||
    die "could not install the credential on $HOST"
  printf 'dsh-remote: imported this client'"'"'s DeepSeek account over ssh (%s)\n' "$HOST"
  imported=1
}

open_url() {
  local url=$1 cmd
  if [ -n "${DSH_BROWSER:-}" ]; then
    # shellcheck disable=SC2086
    set -- ${DSH_BROWSER}
    nohup "$@" "$url" >/dev/null 2>&1 &
    return 0
  fi
  if [ -n "${BROWSER:-}" ]; then
    # shellcheck disable=SC2086
    set -- ${BROWSER}
    nohup "$@" "$url" >/dev/null 2>&1 &
    return 0
  fi
  # xdg-open reports whether this session has a desktop; a browser binary
  # launched directly does not, so it is the fallback, not the default.
  if command -v xdg-open >/dev/null 2>&1 && timeout 10 xdg-open "$url" >/dev/null 2>&1; then
    return 0
  fi
  if command -v wslview >/dev/null 2>&1 && timeout 10 wslview "$url" >/dev/null 2>&1; then
    return 0
  fi
  for cmd in zen firefox chromium chromium-browser brave google-chrome; do
    command -v "$cmd" >/dev/null 2>&1 || continue
    nohup "$cmd" "$url" >/dev/null 2>&1 &
    return 0
  done
  return 1
}

require_host

case "$ACTION" in
  log)
    exec ssh -t "${SSH_OPTS[@]}" "$HOST" "journalctl -u '$SERVICE' -f -o cat"
    ;;
  status)
    state=$(service_state)
    if [ "$state" != active ]; then
      printf 'dsh-remote: %s is %s on %s\n' "$SERVICE" "${state:-unknown}" "$HOST"
      exit 1
    fi
    url=$(read_url)
    [ -n "$url" ] || die "$SERVICE is active on $HOST but has not published a URL"
    printf 'dsh-remote: running on %s\n' "$HOST"
    printf '  ingress   %s\n' "$(clean_url "$url")"
    printf '  port      %s (loopback, behind the proxy)\n' "$PORT"
    if probe_url "$url"; then
      printf '  from here reachable, signed-in token valid\n'
    else
      printf '  from here NOT usable (HTTP %s)\n' "$PROBE_CODE" >&2
      exit 1
    fi
    exit 0
    ;;
  stop)
    unit_cmd stop || exit 1
    printf 'dsh-remote: stopped %s on %s\n' "$SERVICE" "$HOST"
    exit 0
    ;;
  restart)
    old=""
    [ "$(service_state)" = active ] && old=$(read_url)
    unit_cmd restart || exit 1
    URL=$(fresh_url "$old") || die "$SERVICE did not publish a URL within 60s (try: dsh-remote --log)"
    ;;
  url)
    if [ "$(service_state)" != active ]; then
      printf 'dsh-remote: %s is not running on %s\n' "$SERVICE" "$HOST" >&2
      exit 1
    fi
    URL=$(read_url)
    [ -n "$URL" ] || die "$SERVICE is active on $HOST but has not published a URL"
    ;;
  run)
    URL=""
    sync_auth
    if [ "$imported" = 0 ] && [ "$(service_state)" = active ]; then
      URL=$(read_url)
    fi

    # Credentials are read at boot, so an import only takes effect on a restart.
    if [ "$imported" = 1 ] || [ -z "$URL" ]; then
      [ "$imported" = 1 ] && printf 'dsh-remote: restarting %s to pick up the credential\n' "$SERVICE"
      old=$URL
      if [ "$(service_state)" = active ]; then
        unit_cmd restart || exit 1
      else
        printf 'dsh-remote: starting %s on %s\n' "$SERVICE" "$HOST"
        unit_cmd start || exit 1
      fi
      URL=$(fresh_url "$old") || die "$SERVICE did not publish a URL within 60s (try: dsh-remote --log)"
    fi

    if ! probe_url "$URL"; then
      printf 'dsh-remote: %s answered HTTP %s; restarting %s on %s\n' "$(clean_url "$URL")" "$PROBE_CODE" "$SERVICE" "$HOST" >&2
      old=$URL
      unit_cmd restart || exit 1
      URL=$(fresh_url "$old") || die "$SERVICE did not publish a URL within 60s (try: dsh-remote --log)"
      probe_url "$URL" ||
        die "the ingress still answers HTTP $PROBE_CODE on $HOST (nginx / TLS / DNS, not the harness)"
    fi
    ;;
esac

if [ "$ACTION" = url ]; then
  printf '%s\n' "$URL"
  exit 0
fi

if [ "$OPEN_BROWSER" = 1 ]; then
  if open_url "$URL"; then
    printf 'dsh-remote: opened %s\n' "$(clean_url "$URL")"
  else
    printf 'dsh-remote: no browser found here; open this URL yourself:\n\n  %s\n\n' "$URL" >&2
  fi
else
  printf '%s\n' "$URL"
fi

printf 'dsh-remote: harness on %s; this tab does not depend on this command.\n' "$HOST"
