#!/usr/bin/env bash
# bitwarden-ssh-test.sh — log into a fleet host with the SSH key held in Bitwarden,
# authenticated by its fleet-CA certificate instead of by an authorized_keys entry.
#
# Why: the vault holds the private half of an SSH identity whose public half sits at
# ~/.ssh/bitwarden, so nothing on disk can prove that pair works. The certificate at
# ~/.ssh/bitwarden-cert.pub was signed once with the fleet user CA:
#
#   ssh-keygen -s ~/.ssh/user_ca_key \
#     -I "devji@$(hostname)-$(date +%Y%m%d)" -n devji -V +90d ~/.ssh/bitwarden
#
# NOTE: nothing renews that certificate — the weekly `renew-ssh-cert` timer signs only
# ~/.ssh/id_ed25519, and 90 days of validity means it expires on its own. Re-run the
# command above (or declare the key in `ssh.ca` to fold it into the timer).
#
# The check is a real handshake, not an inspection: with BatchMode (no password fallback)
# and IdentitiesOnly, the only credential offered is the extracted key plus its cert, so a
# success cannot be the static authorized_keys entry quietly doing the work. A second run
# without the certificate is the control — if that one is *also* accepted, the key is
# authorized independently and the cert is not the only path to the host.
#
# Interactive by design: unlocking the vault needs the master password, which is why the
# task wrapping this is a human-run check rather than a gate.
#
# env: HOST         target host (default frieren)
#      ITEM         vault item name or id; required when the vault holds >1 SSH key
#      PUBKEY/CERT  key + certificate (default ~/.ssh/bitwarden{,-cert.pub})
#      PRIVATE_KEY  skip Bitwarden and use this key file (tests the handshake half alone)
#      BW_SESSION   reuse an existing vault session instead of unlocking again
# exit: 0 = certificate login succeeded (control result reported), 1 = it failed,
#       2 = preflight failed (missing/expired/mismatched certificate, or no usable key)
set -euo pipefail

HOST="${HOST:-frieren}"
PUBKEY="${PUBKEY:-$HOME/.ssh/bitwarden}"
CERT="${CERT:-$HOME/.ssh/bitwarden-cert.pub}"
ITEM="${ITEM:-}"
KEY_FILE="${PRIVATE_KEY:-}"
own_tmp=""

log() { printf '==> %s\n' "$*"; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}
# The key is only ever on disk for the length of this run. `shred` is best effort on a
# copy-on-write filesystem (the original blocks may survive), so the real control is that
# the file is never written anywhere else and is unlinked even when the handshake fails.
cleanup() {
  if [ -n "$own_tmp" ] && [ -f "$own_tmp" ]; then
    if command -v shred >/dev/null 2>&1; then
      shred -u "$own_tmp" 2>/dev/null || rm -f "$own_tmp"
    else
      rm -f "$own_tmp"
    fi
    log "removed the extracted key from disk"
  fi
}
trap cleanup EXIT

# --- preflight: know exactly which public key the certificate covers ---------------------
[ -f "$PUBKEY" ] || die "public key not found at $PUBKEY"
[ -f "$CERT" ] || die "certificate not found at $CERT (sign it — see the header)"
command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen not found"

pub_fp="$(awk '{print $1" "$2}' "$PUBKEY" | ssh-keygen -lf - | awk '{print $2}')"
cert_fp="$(ssh-keygen -lf "$CERT" | awk '{print $2}')"
[ "$pub_fp" = "$cert_fp" ] || die "$CERT does not cover $PUBKEY (cert $cert_fp vs key $pub_fp)"

cert_summary="$(ssh-keygen -L -f "$CERT")"
cert_ca="$(sed -n 's/.*Signing CA: [^ ]* \([^ ]*\).*/\1/p' <<<"$cert_summary")"
cert_id="$(sed -n 's/.*Key ID: "\(.*\)"/\1/p' <<<"$cert_summary")"
cert_principals="$(awk '/^[[:space:]]*Principals:/{f=1;next} /^[[:space:]]*Critical Options:/{f=0} f{gsub(/^[[:space:]]+|[[:space:]]+$/,""); if ($0 != "") printf "%s,", $0}' <<<"$cert_summary" | sed 's/,$//')"
cert_expiry="$(awk '/^[[:space:]]*Valid:/{print $5}' <<<"$cert_summary")"
log "certificate $CERT (id $cert_id, principals ${cert_principals:-none}, CA $cert_ca, expires $cert_expiry)"
if [ -n "$cert_expiry" ] && [ "$(date -d "$cert_expiry" +%s)" -le "$(date +%s)" ]; then
  die "the certificate expired on $cert_expiry — re-sign the key (see the header)"
fi

# --- obtain the private half -------------------------------------------------------------
if [ -n "$KEY_FILE" ]; then
  log "using PRIVATE_KEY=$KEY_FILE (Bitwarden skipped — handshake-only test)"
  [ -f "$KEY_FILE" ] || die "PRIVATE_KEY=$KEY_FILE does not exist"
  own_tmp=""
else
  command -v bw >/dev/null 2>&1 || die "bw (bitwarden-cli) not found — run this via the checks:ssh:bitwarden task"
  command -v jq >/dev/null 2>&1 || die "jq not found"
  status="$(bw status 2>/dev/null | jq -r '.status // "unknown"')"
  case "$status" in
    unauthenticated) log "not logged in — bw login first (interactive)"; bw login >/dev/null ;;
    unlocked | locked) ;;
    *) log "Bitwarden status: $status" ;;
  esac
  if [ -z "${BW_SESSION:-}" ]; then
    log "unlocking the vault — the master password prompt follows"
    BW_SESSION="$(bw unlock --raw)" || die "could not unlock the vault"
    export BW_SESSION
  fi

  # Every vault item that actually carries an SSH key; picking blindly could test a key
  # the certificate does not cover, which is why an ambiguous vault is an error.
  items="$(bw list items --session "$BW_SESSION" | jq -r '.[] | select((.sshKey.privateKey // "") != "") | [.id, .name] | @tsv')"
  [ -n "$items" ] || die "no vault item holds an SSH key (or pass PRIVATE_KEY= to test the handshake alone)"
  if [ -n "$ITEM" ]; then
    items="$(printf '%s\n' "$items" | grep -iF -- "$ITEM" || true)"
    [ -n "$items" ] || die "no vault item matches ITEM=$ITEM"
  fi
  count="$(printf '%s\n' "$items" | grep -c .)"
  if [ "$count" -ne 1 ]; then
    printf '%s\n' "$items" | sed 's/^/    /' >&2
    die "the vault holds $count SSH keys — pick one with ITEM=<name|id> and run again"
  fi
  item_id="$(printf '%s\n' "$items" | cut -f1)"
  log "vault item: $(printf '%s\n' "$items" | cut -f2)"

  own_tmp="$(mktemp -p "${TMPDIR:-/tmp}" bitwarden-ssh-test.XXXXXX)"
  chmod 600 "$own_tmp"
  bw get item "$item_id" --session "$BW_SESSION" | jq -r '.sshKey.privateKey' >"$own_tmp"
  [ -s "$own_tmp" ] || die "the vault item has an empty private key field"
  KEY_FILE="$own_tmp"
fi

# The extracted key has to be the one the certificate was signed for, otherwise the
# handshake tests a mismatch and the failure would be misread as a CA problem.
# -P "" so a passphrase-protected key fails fast instead of blocking on a prompt that
# BatchMode would refuse later anyway. Compare fingerprints rather than the raw key text:
# `ssh-keygen -y` echoes the key's comment (`devji@nixos`) and can wrap long keys across
# lines, so the string form never matches the public key file byte for byte.
derived_fp="$(ssh-keygen -y -P "" -f "$KEY_FILE" 2>/dev/null | ssh-keygen -lf - 2>/dev/null | awk '{print $2}')" || true
[ -n "$derived_fp" ] ||
  die "that private key could not be read by ssh-keygen without a passphrase (wrong vault item, or a passphrase this check cannot supply)"
[ "$derived_fp" = "$pub_fp" ] ||
  die "the private key ($derived_fp) does not match $PUBKEY ($pub_fp) — the certificate covers a different identity"

# --- the actual test ---------------------------------------------------------------------
# -F /dev/null keeps both runs hermetic: the host config's own CertificateFile/IdentityFile
# settings cannot mask what is being tested here.
cert_result=failed
login_as=""
log "login 1/2: certificate — only this key + cert offered, no password fallback"
if login_out="$(ssh -F /dev/null -o ControlMaster=no -o BatchMode=yes -o IdentitiesOnly=yes \
  -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i "$KEY_FILE" -o CertificateFile="$CERT" \
  "$HOST" 'echo "    LOGIN-OK as $(whoami)@$(hostname)"' 2>&1)"; then
  cert_result=ok
  login_as="$(sed -n 's/.*LOGIN-OK as \(.*\)/\1/p' <<<"$login_out")"
  printf '%s\n' "$login_out"
else
  printf '%s\n' "$login_out" >&2
fi

control_result=failed
log "login 2/2 (control): same key, no certificate — is the cert the only way in?"
if ssh -F /dev/null -o ControlMaster=no -o BatchMode=yes -o IdentitiesOnly=yes \
  -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i "$KEY_FILE" \
  "$HOST" true 2>/dev/null; then
  control_result=ok
fi

# Remove the extracted key as soon as both handshakes are done instead of leaving it to
# the EXIT trap (which still covers an early failure, e.g. a die() from the vault steps).
cleanup
if [ "$cert_result" = "ok" ]; then
  log "PASS: $CERT authenticates to $HOST as ${login_as:-?} (cert principals: ${cert_principals:-none})"
  if [ "$control_result" = "ok" ]; then
    log "note: the same key is also accepted without the certificate, so this host has a"
    log "      static authorized_keys entry for it — the certificate is not the only path."
  else
    log "note: the same key is refused without the certificate — the CA is what authenticated."
  fi
  exit 0
fi
log "FAIL: the certificate login to $HOST did not succeed (see the ssh output above)"
exit 1
