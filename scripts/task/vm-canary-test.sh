#!/usr/bin/env bash
# End-to-end test of the frieren-canary microVM: boot it, prove it is a usable
# sandbox over ssh, stop it, and prove the teardown left nothing running.
#
# The guest is a runbook sandbox, not a web service: it declares no API and frieren
# carries no route to it (both were EXP-102 dogfooding, removed when the guest was
# narrowed to what a runbook needs). So what is asserted here is the sandbox —
# a login, the declared address, the tool set running, a real /var — and that
# `vm:canary:stop` really stops it.
#
# The address is read from the flake, never typed here:
#   lan ip  .?submodules=1#inventory.hosts.frieren-canary.network.lan_ip
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
LAN_IP="$(nix eval --raw ".?submodules=1#inventory.hosts.${NAME}.network.lan_ip")"
[ -n "$LAN_IP" ] || fail "inventory has no lan_ip for ${NAME}"
say "guest ${LAN_IP}"

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

# --- the guest is the declared one ------------------------------------------
GUEST_HOST="$(ssh "${SSH_OPTS[@]}" "${NAME}" hostname)"
[ "$GUEST_HOST" = "$NAME" ] || fail "guest hostname is '${GUEST_HOST}', expected '${NAME}'"
say "guest hostname: ${GUEST_HOST}"

# The declared address, not the alias: `frieren-canary` is a stanza in the host's
# ssh_config, so answering there proves the alias; reaching the inventory value
# directly proves the address the guest was configured with.
ssh "${SSH_OPTS[@]}" "devji@${LAN_IP}" true 2>/dev/null ||
  fail "no answer at the declared address devji@${LAN_IP}"
say "guest address: ${LAN_IP}"

# --- a runbook can run here --------------------------------------------------
# The tool set is what the guest is FOR: a compiler and the query tools a runbook
# reaches for. /var is a real volume rather than the tmpfs overlay, so a runbook
# that writes state does not lose it on a restart and does not silently fill RAM.
# `command -v` is a shell builtin, so this asserts the declared packages are on PATH
# rather than whatever convenience binary happens to exist. One connection, not four.
say "asserting the sandbox's tool set"
ssh "${SSH_OPTS[@]}" "${NAME}" 'for t in jq git gcc make python3 sqlite3; do command -v "$t" >/dev/null || { echo "missing: $t"; exit 1; }; done' ||
  fail "the guest's declared tool set is incomplete (see the loop's output)"
ssh "${SSH_OPTS[@]}" "${NAME}" 'git --version' | grep -q '^git version' ||
  fail "git does not execute in the guest"
say "tools: jq git gcc make python3 sqlite3"

# Pure redirection, so this needs no coreutils in the guest PATH: a writable /var
# volume is what keeps a runbook's state off the tmpfs overlay.
ssh "${SSH_OPTS[@]}" "${NAME}" 'echo ok > /var/tmp/canary-probe && [ "$(< /var/tmp/canary-probe)" = ok ]' ||
  fail "the guest's /var volume is not writable"
say "writable state: /var/tmp/canary-probe"

# --- teardown ----------------------------------------------------------------
say "stopping the guest"
trap - EXIT INT TERM
sudo "$REPO_DIR/scripts/task/run-canary.sh" --stop
wait "$RUNNER_PID" 2>/dev/null || true

say "asserting the teardown left nothing running"
STATUS="$(scripts/task/run-canary.sh --status 2>&1 || true)"
printf '%s\n' "$STATUS" | grep -q 'hypervisor: not running' ||
  fail "a hypervisor is still running after teardown: ${STATUS}"
printf '%s\n' "$STATUS" | grep -q "tap ${NAME}: absent" ||
  fail "the tap outlived the guest: ${STATUS}"

say "canary passed: boot, ssh, declared address, sandbox tooling, teardown"
