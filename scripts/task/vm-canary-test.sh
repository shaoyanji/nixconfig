#!/usr/bin/env bash
# End-to-end test of the frieren-canary microVM: boot it, prove it answers over
# ssh and over the host's reverse proxy, stop it, prove the proxy stops answering.
#
# Every address and port is read from the flake, never typed here:
#   lan ip        .#inventory.hosts.frieren-canary.network.lan_ip
#   api port      .#nixosConfigurations.frieren-canary.config.systemd.services.canary-dummy-api.unitConfig.X-Canary-Api-Port
#
# The previous version hard-coded a Tailscale address that is not in the inventory
# at all, asserted a 504 that nginx only returns on a read timeout, and used
# `curl -f` on the response it expected to fail. This one asserts the guest's
# identity, not just that something answered.
set -euo pipefail

NAME="frieren-canary"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGFILE="/tmp/${NAME}-test.log"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=3)

say() { printf '==> %s\n' "$*"; }
fail() {
  printf 'vm-canary-test: %s\n' "$*" >&2
  [ -f "$LOGFILE" ] && tail -30 "$LOGFILE" >&2
  exit 1
}

cd "$REPO_DIR"

# --- declared facts ----------------------------------------------------------
say "reading the declared contract"
LAN_IP="$(nix eval --raw ".#inventory.hosts.${NAME}.network.lan_ip")"
API_PORT="$(nix eval --raw ".#nixosConfigurations.${NAME}.config.systemd.services.canary-dummy-api.unitConfig.X-Canary-Api-Port")"
[ -n "$LAN_IP" ] || fail "inventory has no lan_ip for ${NAME}"
case "$API_PORT" in
  '' | *[!0-9]*) fail "canary-dummy-api declares no numeric port (got '${API_PORT}')" ;;
esac
say "guest ${LAN_IP}:${API_PORT}"

# --- boot --------------------------------------------------------------------
say "booting (log: ${LOGFILE})"
# the redirect is deliberately the unprivileged shell's: devji must be able to read the log
# shellcheck disable=SC2024
sudo "$REPO_DIR/scripts/task/run-canary.sh" >"$LOGFILE" 2>&1 &
RUNNER_PID=$!
cleanup() {
  if kill -0 "$RUNNER_PID" 2>/dev/null; then
    sudo "$REPO_DIR/scripts/task/run-canary.sh" --stop >/dev/null 2>&1 || true
    wait "$RUNNER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# --- ssh ---------------------------------------------------------------------
say "waiting for ssh (up to 90s; a KVM boot is seconds, TCG is minutes)"
for waited in $(seq 1 90); do
  if ssh "${SSH_OPTS[@]}" "${NAME}" true >/dev/null 2>&1; then
    say "ssh answered after ${waited}s"
    break
  fi
  if ! kill -0 "$RUNNER_PID" 2>/dev/null; then
    fail "the runner exited before ssh answered"
  fi
  [ "$waited" -eq 90 ] && fail "ssh did not answer within 90s"
  sleep 1
done

# --- guest identity ----------------------------------------------------------
GUEST_HOST="$(ssh "${SSH_OPTS[@]}" "${NAME}" hostname)"
[ "$GUEST_HOST" = "$NAME" ] || fail "guest hostname is '${GUEST_HOST}', expected '${NAME}'"
say "guest hostname: ${GUEST_HOST}"

# --- api, direct -------------------------------------------------------------
say "probing the dummy API directly on ${LAN_IP}:${API_PORT}"
DIRECT="$(curl -sS --max-time 5 "http://${LAN_IP}:${API_PORT}/")" || fail "no answer from the guest API"
printf '%s' "$DIRECT" | grep -q '"service": "canary-dummy-api"' || fail "guest API returned unexpected JSON: ${DIRECT}"
printf '%s' "$DIRECT" | grep -q "\"vm\": \"${NAME}\"" || fail "guest API does not identify as ${NAME}: ${DIRECT}"
say "direct API: healthy"

# --- api, through the host proxy --------------------------------------------
# 127.0.0.1 on frieren: the path prefix and the vhost are both host-local, so the
# test does not depend on the tailnet being up or on any address not in the repo.
say "probing /canary/ through the host proxy"
PROXIED="$(curl -sS --max-time 5 "http://127.0.0.1/canary/")" || fail "proxy did not reach the guest"
printf '%s' "$PROXIED" | grep -q '"service": "canary-dummy-api"' || fail "proxy returned unexpected JSON: ${PROXIED}"
VHOST="$(curl -sS --max-time 5 -H "Host: canary.frieren.lan" "http://127.0.0.1/")" || fail "canary.frieren.lan vhost did not answer"
printf '%s' "$VHOST" | grep -q '"service": "canary-dummy-api"' || fail "vhost returned unexpected JSON: ${VHOST}"
say "proxy path and vhost: healthy"

# --- teardown ----------------------------------------------------------------
say "stopping the guest"
trap - EXIT INT TERM
sudo "$REPO_DIR/scripts/task/run-canary.sh" --stop
wait "$RUNNER_PID" 2>/dev/null || true

say "asserting the proxy no longer serves the guest"
CODE="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "http://127.0.0.1/canary/" || echo 000)"
case "$CODE" in
  502 | 503 | 504 | 000) say "proxy returns ${CODE} after teardown (expected)" ;;
  200) fail "proxy still returns 200 after the guest stopped — the VM is still running" ;;
  *) fail "unexpected proxy status after teardown: ${CODE}" ;;
esac

say "canary passed: boot, ssh, guest API, host proxy, teardown"
