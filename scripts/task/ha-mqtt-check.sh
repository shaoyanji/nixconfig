#!/usr/bin/env bash
# ha-mqtt-check.sh — is Home Assistant actually wired to its MQTT broker?
#
# Why: `services.ha-stack` runs Mosquitto and the module's `extraComponents` lists
# `mqtt`, which reads like "MQTT is enabled". It is not. HA's MQTT integration is
# **config-entry only** (see the header of `modules/services/home-assistant.nix`
# for the package-level evidence), so a Nix-declared broker can sit there with
# nothing ever subscribed to it. That is the live HC-5 gap: declared, and not
# wired. This makes the state visible and testable instead of assumed.
#
# Three facts, each from an authoritative source (not a grep of the config):
#   broker up       — the configured listen address:port is listening (ss)
#   entry present   — <configDir>/.storage/core.config_entries has an mqtt entry
#   client attached — the broker has an ESTABLISHED connection (ss)
#
# Exit codes: 0 = HA is wired (entry + a live connection); 1 = the broker is up
#   but HA is NOT wired — the open HC-5 gap, and the reason this task exists;
#   2 = cannot evaluate (ha-stack disabled on the host, nix eval failed, or the
#   broker is not running).
set -uo pipefail

HOST="${HOST:-frieren}"
SUDO="${SUDO:-/run/wrappers/bin/sudo}"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root" || exit 2
for bin in nix jq ss; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "ERROR: $bin is required" >&2
    exit 2
  }
done

# Project to JSON-safe fields only: the module's `extraPackages` is a function
# (`functionTo`), which `--json` cannot serialise — asking for the whole subtree
# fails with a conversion error, not a missing-option error.
cfg_json="$(
  nix eval --json --extra-experimental-features 'nix-command flakes' \
    --apply 'c: {inherit (c) enable configDir; mqtt = {inherit (c.mqtt) address port;};}' \
    ".#nixosConfigurations.${HOST}.config.services.ha-stack" 2>/dev/null
)" || {
  echo "ERROR: nix eval failed for ${HOST}.config.services.ha-stack" >&2
  exit 2
}

if [ "$(jq -r '.enable' <<<"$cfg_json")" != "true" ]; then
  echo "ha-stack is not enabled on ${HOST} — nothing to check."
  exit 2
fi

configDir="$(jq -r '.configDir' <<<"$cfg_json")"
addr="$(jq -r '.mqtt.address' <<<"$cfg_json")"
port="$(jq -r '.mqtt.port' <<<"$cfg_json")"

echo "=== ha mqtt wiring: ${HOST} (broker ${addr}:${port}) ==="

# --- broker listening -----------------------------------------------------------------
broker="no"
ss -ltnH 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${port}\$" && broker="yes"
printf '%-18s %s\n' "broker listening" "$broker"

# --- mqtt config entry present --------------------------------------------------------
entry_file="${configDir}/.storage/core.config_entries"
entries="$("$SUDO" -n cat "$entry_file" 2>/dev/null || cat "$entry_file" 2>/dev/null || true)"
entry="unknown"
if [ -n "$entries" ]; then
  entry="$(jq -r '[.data.entries[]?.domain] | index("mqtt") != null' <<<"$entries" 2>/dev/null || echo unknown)"
fi
printf '%-18s %s\n' "mqtt entry" "$entry"

# --- a client is actually attached ----------------------------------------------------
conns="$(ss -tn 2>/dev/null | grep -E "[:.]${port}\b" | grep -c ESTAB || true)"
printf '%-18s %s\n' "established" "${conns:-0}"

if [ "$broker" != "yes" ]; then
  echo
  echo "ERROR: the broker is not listening on ${addr}:${port} — nothing to be wired to." >&2
  exit 2
fi

echo
if [ "$entry" = "true" ] && [ "${conns:-0}" -gt 0 ]; then
  echo "OK: HA has an mqtt config entry and ${conns} live connection(s) to the broker."
  exit 0
fi

echo "GAP: the broker is running but Home Assistant is not wired to it"
echo "      (entry present: ${entry}, established connections: ${conns:-0})."
echo "      HA's MQTT integration is config-entry only, so a YAML 'mqtt:' stanza"
echo "      would raise 'yaml_setup_without_active_setup' and connect nothing."
echo "      Wire it once in the UI: Settings > Devices & Services > Add Integration"
echo "      > MQTT, broker ${addr}:${port}. Nix cannot declare it (see the module"
echo "      header for why hand-seeding .storage is not acceptable)."
exit 1
