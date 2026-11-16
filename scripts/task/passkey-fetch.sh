#!/usr/bin/env bash
# Pull one passkey out of the vault in the shape a browser driver can import.
#
# A passkey cannot be copied out of the vault UI and does not survive an export:
# the private key lives in `fido2Credentials`, a field only an unlocked CLI
# returns. That is the whole reason this exists — `cloak` is TOTP only, and
# `bw export` omits credentials.
#
#   scripts/task/passkey-fetch.sh                 # rpId google.com
#   RP=github.com OUT=/tmp/gh.json scripts/task/passkey-fetch.sh
#
# RP is the rpId (not the URL), OUT is the destination (0600), SYNC=0 skips the
# sync for an offline read, SEARCH narrows the listing. The key is written to a
# file and never printed: this output is for a transcript.
set -euo pipefail

rp="${RP:-google.com}"
out="${OUT:-${XDG_RUNTIME_DIR:-/tmp}/passkey-${rp//[^a-zA-Z0-9.-]/_}.json}"
search="${SEARCH:-}"

bw="$(command -v bw || true)"
# The flake pins bitwarden-cli, so the store copy is the same binary a shell on
# PATH would run; naming it keeps a host without the package working.
if [ -z "$bw" ]; then
  bw="$(ls -d /nix/store/*-bitwarden-cli-*/bin/bw 2>/dev/null | tail -1 || true)"
fi
[ -n "$bw" ] || {
  echo "passkey-fetch: no bw found (nix shell nixpkgs#bitwarden-cli)" >&2
  exit 3
}

if [ -z "${BW_SESSION:-}" ]; then
  echo "passkey-fetch: BW_SESSION is not set — run 'bw login' and then" >&2
  echo "  export BW_SESSION=\$(bw unlock --raw)" >&2
  exit 3
fi

if [ "${SYNC:-1}" = "1" ]; then
  "$bw" sync >/dev/null 2>&1 ||
    echo "passkey-fetch: sync failed, reading the cached vault" >&2
fi

umask 077
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
if [ -n "$search" ]; then
  "$bw" list items --search "$search" >"$tmp" 2>/dev/null
else
  "$bw" list items >"$tmp" 2>/dev/null
fi || {
  echo "passkey-fetch: bw could not list items (expired session?)" >&2
  exit 3
}

python3 - "$tmp" "$rp" "$out" <<'PY'
import base64, json, sys

src, rp, out = sys.argv[1:4]
items = json.load(open(src))
pick = next(
    (
        c
        for it in items
        for c in ((it.get("login") or {}).get("fido2Credentials") or [])
        if c.get("rpId") == rp
    ),
    None,
)
if not pick:
    print(f"passkey-fetch: no credential for rpId {rp}", file=sys.stderr)
    sys.exit(4)


def dec(s):
    s = s.strip()
    pad = "=" * (-len(s) % 4)
    # Vaultwarden stores base64url; standard base64 shows up in hand-made items.
    if "-" in s or "_" in s:
        return base64.urlsafe_b64decode(s + pad)
    return base64.b64decode(s + pad)


key = dec(pick["keyValue"])
cred = {
    "rpId": pick["rpId"],
    "credentialId": pick["credentialId"].replace("+", "-").replace("/", "_").rstrip("="),
    # The driver's WebAuthn.addCredential wants standard base64, not base64url.
    "privateKey": base64.b64encode(key).decode(),
}
if pick.get("userHandle"):
    cred["userHandle"] = pick["userHandle"].replace("+", "-").replace("/", "_").rstrip("=")

with open(out, "w") as f:
    json.dump(cred, f, indent=2)
print(f"passkey-fetch: rpId {cred['rpId']} -> {out}")
print(
    f"  key {len(key)} bytes (PKCS8), credentialId {len(cred['credentialId'])} chars, "
    f"userHandle {'set' if pick.get('userHandle') else 'absent'}"
)
PY

chmod 600 "$out"
echo "passkey-fetch: holding a credential proves nothing on its own —" >&2
echo "  scripts/task/passkey-probe.sh --from-vault $out is the assertion" >&2
