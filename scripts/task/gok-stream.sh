#!/usr/bin/env bash
# gok-stream — push a built appliance artifact to the running gokrazy device.
#
# This is the second half of `gok update` with nobody's build in it: the device
# takes three streams (PUT /update/{root,boot,mbr}, then switch, then reboot —
# github.com/gokrazy/updater) and answers a sha256 for each one. The artifact is
# whatever `gok.sh build` wrote.
#
# It is a separate script because it runs on the ARTIFACT HOST, not on the machine
# that built the image: delphi already holds the tarball and sits on the tailnet,
# so `task infra:gok:deploy` pipes this file over ssh and pushes from there
# instead of dragging ~140 MB back to a laptop to send it forward again.
#
#   gok-stream.sh [--stage|--testboot] <artifact-dir>
#
#   dir                 root.squashfs + boot.fat + mbr.img + manifest.json +
#                       SHA256SUMS, exactly what gok.sh build leaves behind
#   --stage             write the streams, do not switch roots or reboot: the
#                       appliance keeps running what it has
#   --testboot          switch, boot the new root once, and let gokrazy revert if
#                       it does not report back
#
# Credentials, in order: $GOK_HTTP_PASSWORD, then $GOK_PUSH_PASSWORD_FILE (a
# root-only file, which is how the deploy hands it over without putting it in a
# command line other local users can read in `ps`). Target, in order:
# $GOK_PUSH_URL, then the artifact manifest's hostname.
set -euo pipefail

stage=false
testboot=false
dir=''
for arg in "$@"; do
  case $arg in
    --stage) stage=true ;;
    --testboot) testboot=true ;;
    *) dir=$arg ;;
  esac
done

die() {
  echo "gok-stream: $*" >&2
  exit 1
}

[ -n "$dir" ] || die "usage: gok-stream.sh [--stage|--testboot] <artifact-dir>"
[ -f "$dir/root.squashfs" ] || die "no root.squashfs in '$dir' — is that a built artifact?"

# The streams are the ones that get written to the device, so they are verified
# first: a truncated Taildrop transfer or a half-copied directory would otherwise
# be streamed in full and rejected only by the device, after the boot partition
# has already been rewritten.
(cd "$dir" && sha256sum -c --quiet SHA256SUMS) ||
  die "artifact does not match its SHA256SUMS — refusing to write it to the appliance"

pw=${GOK_HTTP_PASSWORD:-}
if [ -z "$pw" ] && [ -n "${GOK_PUSH_PASSWORD_FILE:-}" ]; then
  pw=$(<"$GOK_PUSH_PASSWORD_FILE")
fi
[ -n "$pw" ] || die "no update password (GOK_HTTP_PASSWORD or GOK_PUSH_PASSWORD_FILE)"

base=${GOK_PUSH_URL:-}
if [ -z "$base" ]; then
  host=$(jq -r '.hostname // empty' "$dir/manifest.json" 2>/dev/null || true)
  [ -n "$host" ] || die "no GOK_PUSH_URL and no hostname in the manifest"
  base=http://$host/
fi
base=${base%/}/

want=$(jq -r '.buildTimestamp // ""' "$dir/manifest.json" 2>/dev/null || true)
echo "gok-stream: pushing to $base (artifact build ${want:-unknown})" >&2
echo "gok-stream: credentials in this artifact: $(jq -c '.credentials // "not recorded"' "$dir/manifest.json" 2>/dev/null || echo 'not recorded')" >&2

# No X-Gokrazy-Update-Hash header on purpose: sending it makes the device answer a
# crc32 instead of a sha256, and sha256 is what sha256sum computes here. The cost
# is a few seconds of hashing on the Pi, not a byte of trust.
body=$(mktemp "${TMPDIR:-/tmp}/gok-body.XXXXXX")
trap 'rm -f "$body"' EXIT

for stream in root boot mbr; do
  case $stream in
    root) file=root.squashfs ;;
    boot) file=boot.fat ;;
    mbr) file=mbr.img ;;
  esac
  sent=$(sha256sum "$dir/$file" | cut -d' ' -f1)
  # No -s: `-s` kills the meter, and a silent 107 MB upload is the symptom that
  # made the old CI job unreadable. The response body still goes to $body.
  code=$(curl -S --progress-bar -m 900 -u "gokrazy:$pw" -T "$dir/$file" \
    -o "$body" -w '%{http_code}' "${base}update/$stream") ||
    die "PUT update/$stream did not complete (transport)"
  if [ "$code" != 200 ]; then
    # The MBR handler is the one gokrazy may not implement; gok ignores that too,
    # and an A/B update boots on the existing MBR.
    if [ "$stream" = mbr ]; then
      echo "gok-stream: mbr: no MBR handler on the target (HTTP $code), keeping the existing one" >&2
      continue
    fi
    die "PUT update/$stream -> HTTP $code: $(cat "$body")"
  fi
  got=$(cat "$body")
  [ "$got" = "$sent" ] || die "$stream: device received $got, artifact is $sent"
  echo "gok-stream: $stream ok ($(stat -c %s "$dir/$file") bytes, sha256 verified by the device)" >&2
done

if $stage; then
  echo "gok-stream: staged on the inactive partition; the appliance is still on its old root" >&2
  exit 0
fi

action=switch
$testboot && action=testboot
code=$(curl -sS -m 60 -X POST -u "gokrazy:$pw" -o /dev/null -w '%{http_code}' "${base}update/$action") || true
[ "$code" = 200 ] ||
  die "update/$action -> HTTP ${code:-none}; the new root is written but not active"

# The device drops the connection when it reboots, so a transport failure here is
# the expected outcome rather than an error.
curl -sS -m 60 -X POST -u "gokrazy:$pw" -o /dev/null "${base}reboot" 2>/dev/null || true

# The device reports this timestamp from `/` once it has booted the new root,
# which is what distinguishes "it is up" from "it is up on THIS artifact".
deadline=$((SECONDS + 300))
got=''
echo "gok-stream: waiting up to 5 min for the appliance to report build ${want:-unknown}" >&2
while [ "$SECONDS" -lt "$deadline" ]; do
  sleep 5
  got=$(curl -sS -m 5 -u "gokrazy:$pw" -H 'Accept: application/json' "$base" 2>/dev/null |
    jq -r '.BuildTimestamp // empty' 2>/dev/null || true)
  [ -n "$got" ] || continue
  if [ -z "$want" ] || [ "$got" = "$want" ]; then
    echo "gok-stream: appliance is up on build $got" >&2
    exit 0
  fi
done
die "appliance never reported build ${want}. Last seen: ${got:-no answer}. Read its console or web UI before retrying."
