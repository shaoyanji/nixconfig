#!/usr/bin/env bash
# Ephemeral Canary MicroVM Runner (EXP-102)
# Orchestrates tap interface, virtiofsd daemons, and cloud-hypervisor.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_DIR="/var/lib/microvms/frieren-canary/run"
BIN_DIR="$REPO_DIR/result-canary/bin"

if [ ! -d "$BIN_DIR" ]; then
  echo "Error: result-canary not found. Build with: task vm:canary:build" >&2
  exit 1
fi

mkdir -p "$RUN_DIR"
cd "$RUN_DIR"

cleanup() {
  echo "==> Shutting down canary runners and virtiofsd..."
  if [ -n "${VIRTIO1_PID:-}" ]; then kill "$VIRTIO1_PID" 2>/dev/null || true; fi
  if [ -n "${VIRTIO2_PID:-}" ]; then kill "$VIRTIO2_PID" 2>/dev/null || true; fi
  pkill -f "virtiofsd-ro-store" 2>/dev/null || true
  pkill -f "virtiofsd-ssh-keys" 2>/dev/null || true
  pkill -f "microvm@frieren-canary" 2>/dev/null || true
  rm -f frieren-canary*.sock notify.vsock* *.pid 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "==> [1/4] Preparing TAP interface microvm1..."
"$BIN_DIR/tap-up"
ip link set microvm1 master brlan 2>/dev/null || true

echo "==> [2/4] Cleaning stale runtime state..."
rm -f frieren-canary*.sock notify.vsock* *.pid 2>/dev/null || true

# Extract the exact virtiofsd store and key runners from the supervisord config
SUPERVISOR_CONF=$(grep -o '/nix/store/[^ ]*-frieren-canary-virtiofsd-supervisord.conf' "$BIN_DIR/virtiofsd-run" | head -n1)
RO_STORE_CMD=$(grep 'command=' "$SUPERVISOR_CONF" | grep 'ro-store' | cut -d= -f2)
SSH_KEYS_CMD=$(grep 'command=' "$SUPERVISOR_CONF" | grep 'ssh-keys' | cut -d= -f2)

echo "==> [3/4] Starting virtiofsd daemons..."
$RO_STORE_CMD &
VIRTIO1_PID=$!
$SSH_KEYS_CMD &
VIRTIO2_PID=$!

for i in $(seq 1 40); do
  if [ -S "frieren-canary-virtiofs-ro-store.sock" ] && [ -S "frieren-canary-virtiofs-ssh-keys.sock" ]; then
    echo "==> Virtiofs sockets ready in ${i}00ms"
    break
  fi
  sleep 0.1
done

if [ ! -S "frieren-canary-virtiofs-ro-store.sock" ] || [ ! -S "frieren-canary-virtiofs-ssh-keys.sock" ]; then
  echo "ERROR: Failed to initialize virtiofs sockets within 4s" >&2
  exit 1
fi

echo "==> [4/4] Starting cloud-hypervisor (frieren-canary)..."
"$BIN_DIR/microvm-run"
