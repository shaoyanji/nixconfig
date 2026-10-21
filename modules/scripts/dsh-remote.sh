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
OPEN_ERROR=""
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
  dsh-remote --login         give the worker a DeepSeek account: sign in once
                             through a temporary loopback forward (the only
                             callback origin upstream accepts)
  dsh-remote --sync-auth     re-import this client's DeepSeek credential
  dsh-remote --no-sync-auth  never import it; sign in through the Web UI instead
  dsh-remote --no-browser    print the URL instead of opening a browser
  dsh-remote --host <host>   another worker (default delphi.bountystash.com)

The harness runs on the worker and binds loopback there; the worker serves it at
https://<host>/deepseek/ behind its own TLS vhost. Nothing is tunneled from this
machine, so closing this command does not close the tab. The first visit to a
browser profile exchanges the printed token for a 30-day cookie, after which the
bare https://<host>/deepseek/ works on its own.

Env: DSH_HOST DSH_SERVICE DSH_PORT DSH_SYNC_AUTH DSH_OPEN_BROWSER DSH_BROWSER
     DSH_TIMEOUT DSH_WAIT DSH_OPEN_TIMEOUT
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
    --login) ACTION=login; shift ;;
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

# A start or restart mints a new token, so "the URL changed" is how we know the
# line we read belongs to the process that is running now — the journal keeps
# every previous start, and acting on a stale line is a 401 (or a 502 while the
# new process has not bound yet).
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

# The URL line is printed as soon as the harness is up, which can be a beat
# before the listener accepts — a 502 here is a race, not a broken ingress.
wait_probe() {
  local url=$1 deadline=$((SECONDS + ${DSH_WAIT:-45}))
  while :; do
    probe_url "$url" && return 0
    [ "$SECONDS" -ge "$deadline" ] && return 1
    sleep 1
  done
}

worker_root() {
  remote <<'REMOTE' 2>/dev/null | sed -n 's/^DSHROOT://p' | tail -1
printf 'DSHROOT:%s\n' "${DSH_HOME:-$HOME/.dsh}"
REMOTE
}

# "Signed in" means the DeepSeek platform grant is in the harness home on the
# worker. The credential lives there, not in this client, and not in the tab.
worker_signed_in() {
  local path=${1:-} out
  [ -n "$path" ] || path=$(worker_root)/.credentials.yaml
  out=$(remote "$path" <<'REMOTE' 2>/dev/null || true
if grep -qs 'deepseek-account-platform/default' "$1"; then printf 'SIGNED\n'; else printf 'UNSIGNED\n'; fi
REMOTE
  )
  [ "$(printf '%s\n' "$out" | tail -1)" = SIGNED ]
}

# Credentials travel inside the ssh channel, never on a command line, and the
# worker's own account is not overwritten with this client's: a worker that is
# already signed in wins unless the operator asks for the import.
imported=0
sync_auth() {
  local root remote_creds local_creds
  [ "$SYNC_AUTH" = never ] && return 0
  local_creds="${DSH_HOME:-$HOME/.dsh}/.credentials.yaml"
  [ -r "$local_creds" ] || return 0
  grep -qs 'deepseek-account-platform/default' "$local_creds" || return 0

  root=$(worker_root)
  [ -n "$root" ] || return 0
  remote_creds="$root/.credentials.yaml"

  if [ "$SYNC_AUTH" != always ] && worker_signed_in "$remote_creds"; then
    return 0
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
  local url=$1 cmd out
  OPEN_ERROR=""
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
  # The desktop's own handler is the right first move: it is what a click on a
  # link uses, so it already resolves through mime-apps (`zen-beta.desktop`
  # here). The timeout is generous on purpose — a cold handoff through the
  # portal has been measured at ~10 s, and killing it reported "no browser"
  # while a tab was in fact about to appear.
  if command -v xdg-open >/dev/null 2>&1; then
    if out=$(timeout "${DSH_OPEN_TIMEOUT:-25}" xdg-open "$url" 2>&1); then
      return 0
    fi
    OPEN_ERROR=${out:-xdg-open timed out after ${DSH_OPEN_TIMEOUT:-25}s}
  fi
  if command -v wslview >/dev/null 2>&1; then
    if out=$(timeout "${DSH_OPEN_TIMEOUT:-25}" wslview "$url" 2>&1); then
      return 0
    fi
    OPEN_ERROR=${out:-wslview failed}
  fi
  # No handler, or one that refuses: the binaries themselves, newest first.
  for cmd in zen-beta zen firefox librewolf chromium chromium-browser brave google-chrome; do
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
    if worker_signed_in; then
      printf '  account   signed in (the worker holds the credential)\n'
    else
      printf '  account   NONE — dsh-remote --login\n'
    fi
    exit 0
    ;;
  stop)
    unit_cmd stop || exit 1
    printf 'dsh-remote: stopped %s on %s\n' "$SERVICE" "$HOST"
    exit 0
    ;;
  restart)
    old=$(read_url)
    unit_cmd restart || exit 1
    URL=$(fresh_url "$old") || die "$SERVICE did not publish a URL within 60s (try: dsh-remote --log)"
    ;;
  login)
    root=$(worker_root)
    creds="$root/.credentials.yaml"
    if worker_signed_in "$creds"; then
      printf 'dsh-remote: %s is already signed in (%s)\n' "$HOST" "$creds"
      exit 0
    fi

    if [ "$(service_state)" != active ]; then
      printf 'dsh-remote: starting %s on %s\n' "$SERVICE" "$HOST"
      unit_cmd start || exit 1
    fi
    URL=$(read_url)
    [ -n "$URL" ] || URL=$(fresh_url "") || die "$SERVICE did not publish a URL within 60s (try: dsh-remote --log)"
    case "$URL" in
      *\?*) QUERY=${URL#*\?} ;;
      *) die "the worker published an URL without a token: $URL" ;;
    esac

    # DeepSeek's OAuth callback is accepted ONLY on a browser loopback origin
    # with an explicit port — upstream's rule ("remote domains and path-based
    # proxies are unsupported"), and the UI sends window.location.origin. So the
    # sign-in runs on the origin root over a private forward, and the forward
    # closes itself the moment the worker's credential exists.
    LPORT=${DSH_LOGIN_PORT:-3090}
    while (exec 3<>"/dev/tcp/127.0.0.1/$LPORT") 2>/dev/null; do LPORT=$((LPORT + 1)); done
    ssh -N -o BatchMode=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=20 \
      -L "127.0.0.1:$LPORT:127.0.0.1:$PORT" "$HOST" &
    FWD=$!
    trap 'kill "$FWD" 2>/dev/null || true' EXIT

    LOGIN_URL="http://127.0.0.1:$LPORT/?$QUERY"
    for _ in $(seq 1 40); do
      curl -sS -o /dev/null -m 2 "http://127.0.0.1:$LPORT/" 2>/dev/null && break
      kill -0 "$FWD" 2>/dev/null || die "the loopback forward to $HOST:$PORT exited"
      sleep 0.25
    done

    printf 'dsh-remote: signing in on a loopback origin (%s),\n' "http://127.0.0.1:$LPORT/"
    printf '             because DeepSeek will not call back through a path proxy.\n'
    if [ "$OPEN_BROWSER" = 1 ] && open_url "$LOGIN_URL"; then
      :
    else
      printf 'dsh-remote: open this and sign in:\n\n  %s\n\n' "$LOGIN_URL"
    fi
    printf 'dsh-remote: the forward closes itself once %s has the account.\n' "$HOST"

    WAIT=${DSH_LOGIN_WAIT:-300}
    for _ in $(seq 1 $((WAIT / 2))); do
      if worker_signed_in "$creds"; then
        printf 'dsh-remote: %s is signed in; use dsh-remote (or %s) from now on.\n' "$HOST" "$(clean_url "$URL")"
        exit 0
      fi
      kill -0 "$FWD" 2>/dev/null || die "the loopback forward exited before the sign-in completed"
      sleep 2
    done
    die "no sign-in after ${WAIT}s; $HOST still has no DeepSeek account"
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
    # Baseline from BEFORE we act: the journal holds every previous start, and a
    # stopped unit's last line is not the process we are about to launch.
    old=$(read_url)
    if [ "$imported" = 0 ] && [ "$(service_state)" = active ]; then
      URL=$(read_url)
    fi

    # Credentials are read at boot, so an import only takes effect on a restart.
    if [ "$imported" = 1 ] || [ -z "$URL" ]; then
      [ "$imported" = 1 ] && printf 'dsh-remote: restarting %s to pick up the credential\n' "$SERVICE"
      if [ "$(service_state)" = active ]; then
        unit_cmd restart || exit 1
      else
        printf 'dsh-remote: starting %s on %s\n' "$SERVICE" "$HOST"
        unit_cmd start || exit 1
      fi
      URL=$(fresh_url "$old") || die "$SERVICE did not publish a URL within 60s (try: dsh-remote --log)"
    fi

    if ! wait_probe "$URL"; then
      printf 'dsh-remote: %s answered HTTP %s; restarting %s on %s\n' "$(clean_url "$URL")" "$PROBE_CODE" "$SERVICE" "$HOST" >&2
      old=$URL
      unit_cmd restart || exit 1
      URL=$(fresh_url "$old") || die "$SERVICE did not publish a URL within 60s (try: dsh-remote --log)"
      wait_probe "$URL" ||
        die "the ingress still answers HTTP $PROBE_CODE on $HOST (nginx / TLS / DNS, not the harness)"
    fi

    # The tab loads without an account, but upstream refuses the OAuth callback
    # through a path prefix, so saying nothing would leave the user clicking a
    # Sign-in button that cannot succeed.
    if [ "$imported" = 0 ] && ! worker_signed_in; then
      printf 'dsh-remote: %s has no DeepSeek account, and the ingress cannot finish a sign-in\n' "$HOST" >&2
      printf 'dsh-remote:   dsh-remote --login       sign in here, through a temporary loopback forward\n' >&2
      printf 'dsh-remote:   dsh-remote --sync-auth   import it from a client that is signed in\n' >&2
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
    printf 'dsh-remote: no browser took the URL%s; open it yourself:\n\n  %s\n\n' \
      "${OPEN_ERROR:+ ($OPEN_ERROR)}" "$URL" >&2
    printf 'dsh-remote: set DSH_BROWSER to a browser command to force one.\n' >&2
  fi
else
  printf '%s\n' "$URL"
fi

printf 'dsh-remote: harness on %s; this tab does not depend on this command.\n' "$HOST"
