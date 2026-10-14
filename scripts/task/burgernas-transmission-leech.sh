#!/usr/bin/env bash
# Apply the shared leech-only Transmission policy to BurgerNAS's SynoCommunity
# Transmission daemon. The live settings live on the NAS at
# /volume1/@appdata/transmission/settings.json and are owned by
# `sc-transmission`, so applying them needs root on the NAS.
#
# The NAS sudo password is read from /run/secrets/nas. That file is rendered
# from SOPS (`sops.secrets."burgernas-sudo-password"` in
# hosts/frieren/configuration.nix, key `burgernas-sudo-password` in
# modules/secrets.yaml) — do not create it by hand; rotate via sops. The only
# NAS-side writes are the settings file plus a timestamped backup under
# /root; the daemon is stopped first so its shutdown save cannot clobber ours.
set -euo pipefail

ALIAS="${BURGERNAS_ALIAS:-burgernas}"
CRED="/run/secrets/nas"
REMOTE_SETTINGS=/volume1/@appdata/transmission/settings.json

if [ ! -f "$CRED" ]; then
  echo "ERROR: NAS credential file $CRED not found." >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "==> Fetching live settings and applying the leech-only policy ..."
ssh "$ALIAS" "cat $REMOTE_SETTINGS" | jq --indent 4 '. + {
  "ratio-limit-enabled": true,
  "ratio-limit": 0,
  "idle-seeding-limit-enabled": true,
  "idle-seeding-limit": 1,
  "speed-limit-up-enabled": true,
  "speed-limit-up": 1,
  "upload-slots-per-torrent": 1,
  "dht-enabled": false,
  "pex-enabled": false,
  "lpd-enabled": false,
  "port-forwarding-enabled": false,
  "encryption": 2
}' > "$work/settings.json"

echo "==> Staging settings + apply script on the NAS ..."
ssh "$ALIAS" 'mkdir -p "$HOME/tmp" && cat > "$HOME/tmp/tx-settings.json"' < "$work/settings.json"
ssh "$ALIAS" 'cat > "$HOME/tmp/apply-tx.sh"' <<'REMOTE'
set -e
SETTINGS=/volume1/@appdata/transmission/settings.json
cp -a "$SETTINGS" "/root/transmission-settings.json.bak-$(date +%Y%m%d-%H%M%S)"
/bin/systemctl stop pkgctl-transmission.service || true
sleep 1
cp /var/services/homes/devji/tmp/tx-settings.json "$SETTINGS"
chown sc-transmission:synocommunity "$SETTINGS"
chmod 0664 "$SETTINGS"
/bin/systemctl start pkgctl-transmission.service
sleep 3
echo "unit=$(/bin/systemctl is-active pkgctl-transmission.service)"
grep -E '"(ratio-limit|ratio-limit-enabled|idle-seeding-limit|speed-limit-up|upload-slots-per-torrent|dht-enabled|pex-enabled|lpd-enabled|port-forwarding-enabled|encryption)"' "$SETTINGS"
REMOTE

echo "==> Applying on the NAS (root) ..."
printf '%s\n' "$(cat "$CRED")" | ssh "$ALIAS" 'sudo -S bash "$HOME/tmp/apply-tx.sh"'

echo "==> Done. BurgerNAS Transmission now runs the shared leech-only policy."
