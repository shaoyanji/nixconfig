#!/usr/bin/env bash
# Google Drive via rclone on one host: run the OAuth handshake, or prove the
# remote still works.
#
#   drive-auth.sh verify                 quota + top-level dirs; exits non-zero when the token is dead
#   drive-auth.sh auth [--funnel] [--remote gdrive] [--force]
#                                        the handshake; --funnel exposes rclone's
#                                        loopback callback on the tailnet for a
#                                        browser on another machine
#   drive-auth.sh stop-funnel            tear down a funnel left behind
#
# Client id/secret come from GDRIVE_CLIENT_ID / GDRIVE_CLIENT_SECRET, else from
# the sops plane (`googleDrive/clientId`, `googleDrive/clientSecret`).
set -euo pipefail

REMOTE=${REMOTE:-gdrive}
# rclone's authorize server always takes this port; it is what the funnel or the
# ssh -L tunnel has to point at.
PORT=${DRIVE_AUTH_PORT:-53682}
WAIT=${DRIVE_AUTH_WAIT:-300}
NIXCONFIG=${NIXCONFIG:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}

die() {
  echo "drive-auth: $*" >&2
  exit 1
}

need() { command -v "$1" >/dev/null || die "$1 is not installed"; }

creds() {
  if [ -z "${GDRIVE_CLIENT_ID:-}" ] && [ -f "$NIXCONFIG/modules/secrets.yaml" ] && command -v sops >/dev/null; then
    GDRIVE_CLIENT_ID=$(cd "$NIXCONFIG" && sops -d --extract '["googleDrive"]["clientId"]' modules/secrets.yaml 2>/dev/null || true)
    GDRIVE_CLIENT_SECRET=$(cd "$NIXCONFIG" && sops -d --extract '["googleDrive"]["clientSecret"]' modules/secrets.yaml 2>/dev/null || true)
  fi
  [ -n "${GDRIVE_CLIENT_ID:-}" ] && [ -n "${GDRIVE_CLIENT_SECRET:-}" ] ||
    die "no OAuth client — export GDRIVE_CLIENT_ID and GDRIVE_CLIENT_SECRET, or run where sops can read the repo"
}

remote_exists() { rclone listremotes 2>/dev/null | grep -qx "$REMOTE:"; }

verify() {
  need rclone
  remote_exists || die "no '$REMOTE:' remote on this host — run: drive-auth.sh auth"
  # A dead token fails here with rclone's own words ("invalid_grant",
  # "token expired"), which is more useful than a timeout from a mount.
  timeout 30 rclone lsd "$REMOTE:" --max-depth 1 2>&1 | head -20 || die "$REMOTE: is not answering — token may be expired: rclone config reconnect $REMOTE:"
  timeout 30 rclone about "$REMOTE:" 2>/dev/null | sed 's/^/  /' || echo "  (no quota reported)"
  echo "drive-auth: $REMOTE: ok"
}

stop_funnel() {
  command -v tailscale >/dev/null || return 0
  tailscale funnel "$PORT" off >/dev/null 2>&1 || true
}

auth() {
  need rclone
  local funnel=0 force=0
  while [ $# -gt 0 ]; do
    case "$1" in
    --funnel) funnel=1 && shift ;;
    --force) force=1 && shift ;;
    --remote) REMOTE=${2:?--remote needs a name} && shift 2 ;;
    *) die "unknown flag $1" ;;
    esac
  done
  remote_exists && [ "$force" = 0 ] && die "'$REMOTE:' already exists — use 'drive-auth.sh verify', 'rclone config reconnect $REMOTE:', or --force"
  creds

  log=$(mktemp)
  payload=$(printf '{"client_id":"%s","client_secret":"%s","scope":"drive"}' "$GDRIVE_CLIENT_ID" "$GDRIVE_CLIENT_SECRET")
  # --auth-no-open-browser: on a headless host, "open a browser" means hang.
  rclone authorize drive "$payload" --auth-no-open-browser >"$log" 2>&1 &
  pid=$!
  cleanup() {
    kill "$pid" 2>/dev/null || true
    [ "$funnel" = 1 ] && stop_funnel
    rm -f "$log"
  }
  trap cleanup EXIT

  # Wait for rclone to print the local URL: that line is the only place the
  # state token appears, and the state is what binds the browser to this process.
  url="" local_url=""
  for _ in $(seq 1 60); do
    local_url=$(grep -oE "http://127\.0\.0\.1:$PORT/auth\?state=[A-Za-z0-9]+" "$log" | head -1 || true)
    [ -n "$local_url" ] && break
    kill -0 "$pid" 2>/dev/null || die "rclone authorize exited before printing a URL: $(tail -3 "$log")"
    sleep 0.5
  done
  [ -n "$local_url" ] || die "no auth URL after 30s: $(tail -3 "$log")"
  url=$local_url

  if [ "$funnel" = 1 ]; then
    command -v tailscale >/dev/null || die "tailscale is not installed, so --funnel cannot work"
    tailscale funnel "$PORT" on >/dev/null 2>&1 || die "tailscale funnel $PORT failed — check 'tailscale funnel status' and that HTTPS is enabled for the tailnet"
    echo "drive-auth: funnel on :$PORT for this run; it is torn down on exit" >&2
    dns=$(tailscale status --json | jq -r '.Self.DNSName' | sed 's/\.$//')
    [ -n "$dns" ] && [ "$dns" != null ] || die "tailscale reports no MagicDNS name — the funnel URL cannot be built"
    # Path and state are rclone's; only the host changes.
    url=$(printf '%s' "$local_url" | sed "s|http://127.0.0.1:$PORT|https://$dns|")
  fi

  cat >&2 <<EOF
Open this URL in a browser and approve the app:

  $url

Waiting up to ${WAIT}s for the token (Ctrl-C aborts and tears the funnel down).
EOF

  # rclone prints the token as the last JSON object in its output once consent
  # lands; it then exits 0.
  waited=0
  while kill -0 "$pid" 2>/dev/null; do
    [ "$waited" -ge "$WAIT" ] && die "no token after ${WAIT}s — the browser step never completed"
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid" || die "rclone authorize failed: $(tail -3 "$log")"

  token=$(sed -n '/^{/,$p' "$log" | tr -d '\n' | grep -oE '\{.*\}' | tail -1)
  [ -n "$token" ] || die "rclone exited without a token — rerun; if it keeps happening the app may be missing the redirect URI 127.0.0.1"
  rclone config create "$REMOTE" drive \
    client_id "$GDRIVE_CLIENT_ID" client_secret "$GDRIVE_CLIENT_SECRET" \
    token "$token" --non-interactive >/dev/null || die "rclone could not write the '$REMOTE' config"
  rm -f "$log"
  [ "$funnel" = 1 ] && stop_funnel
  echo "drive-auth: '$REMOTE:' configured" >&2
  verify
}

cmd=${1:-verify}
shift || true
case "$cmd" in
verify) verify ;;
auth) auth "$@" ;;
stop-funnel) stop_funnel && echo "drive-auth: funnel off" ;;
-h | --help) sed -n '2,14p' "$0" ;;
*) die "unknown command '$cmd' — verify | auth | stop-funnel" ;;
esac
