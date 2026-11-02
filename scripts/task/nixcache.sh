#!/usr/bin/env bash
# nixcache.sh — the edge cache's only imperative surface.
#
# WHERE THE FACTS LIVE: the bucket name, priority and routes are in
# modules/services/nix-cache-edge/wrangler.toml; the credentials are already in
# the sops apikeys plane (CLOUDFLARE.{ACCOUNT.ID,API.TOKEN,ACCESS.KEY.ID,
# SECRET.ACCESS.KEY,S3.API.ENDPOINT}) and are read at run time with the user's
# age key, so nothing here is declared in Nix and no rebuild is involved.
#
# UPLOADS ARE NOT HERE ON PURPOSE. A narinfo must be signed by whoever writes it;
# the edge only reads. `push` exists so a local test writes through the same S3
# path CI uses (`nix copy --to s3://…`), with the signing key passed through
# NIX_CONFIG so it never appears in a process listing.
#
# Usage: nixcache.sh check|deploy|probe|size|keygen|push [args]
# docs/nix-cache-edge.md
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
project="$repo/modules/services/nix-cache-edge"
secrets="$repo/modules/secrets/apikeys.yaml"

BUCKET="nix-cache"
BUDGET_GIB="${BUDGET_GIB:-10}"
SIGNING_KEY_PATH='["NIXCACHE"]["SIGNING"]["KEY"]'

die() {
  echo "nixcache: $*" >&2
  exit 1
}

need_secrets() {
  [ -f "$secrets" ] || die "$secrets missing (is the modules/secrets submodule checked out?)"
}

# `sops -d` on a YAML file emits YAML, so ask for JSON and read it with jq.
secret() {
  sops -d --output-type json "$secrets" | jq -er "$1" || die "sops has no $1"
}

load_cloudflare() {
  need_secrets
  export CLOUDFLARE_API_TOKEN="$(secret '.["CLOUDFLARE"]["API"]["TOKEN"]')"
  export CLOUDFLARE_ACCOUNT_ID="$(secret '.["CLOUDFLARE"]["ACCOUNT"]["ID"]')"
}

# rclone speaks R2's S3 API; env-only config keeps a credential out of a file.
load_s3_env() {
  need_secrets
  export RCLONE_CONFIG_R2_TYPE=s3
  export RCLONE_CONFIG_R2_PROVIDER=Cloudflare
  export RCLONE_CONFIG_R2_ACCESS_KEY_ID="$(secret '.["CLOUDFLARE"]["ACCESS"]["KEY"]["ID"]')"
  export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$(secret '.["CLOUDFLARE"]["SECRET"]["ACCESS"]["KEY"]')"
  export RCLONE_CONFIG_R2_ENDPOINT="$(secret '.["CLOUDFLARE"]["S3"]["API"]["ENDPOINT"]')"
}

endpoint_url() {
  secret '.["CLOUDFLARE"]["S3"]["API"]["ENDPOINT"]'
}

wrangler() {
  command -v wrangler >/dev/null || die "wrangler is not on PATH (hosts/delphi/nix-cache-edge.nix installs it)"
  # `command` is what keeps this a check rather than recursion: the bare name
  # resolves back to this function, which is a stack overflow, not a deploy.
  command wrangler "$@"
}

case "${1:-}" in
check)
  # Offline: the routing rules and the worker against a stub bucket, then a real
  # bundle. No token, no account, no bucket — this is the pre-deploy gate.
  command -v node >/dev/null || die "node is not on PATH (hosts/delphi/nix-cache-edge.nix installs it)"
  node --test "$project"/src/routes.test.ts "$project"/src/worker.test.ts
  # wrangler resolves wrangler.toml from the working directory, and without one it
  # enters its interactive setup path (which SIGSEGVs in a non-TTY). cd, always.
  (cd "$project" && CLOUDFLARE_API_TOKEN=dummy wrangler deploy --dry-run --outdir "${TMPDIR:-/tmp}/nixcache-dryrun") |
    sed -n '/Total Upload/,$p'
  ;;

deploy)
  load_cloudflare
  # A create on an existing bucket is success; anything else (R2 not enabled on
  # the account, a token without R2:Edit) must stop the run, not be swallowed.
  if ! out="$(wrangler r2 bucket create "$BUCKET" 2>&1)"; then
    if grep -q 'already exists\|already owned' <<<"$out"; then
      echo "nixcache: bucket $BUCKET already exists"
    else
      printf '%s\n' "$out" >&2
      die "could not create bucket $BUCKET"
    fi
  else
    printf '%s\n' "$out" | tail -2
  fi
  (cd "$project" && wrangler deploy)
  ;;

probe)
  url="${URL:-}"
  [ -n "$url" ] || die "URL=https://… required"
  url="${url%/}"

  info="$(curl -fsS --max-time 10 "$url/nix-cache-info")" || die "$url/nix-cache-info unreachable"
  grep -qx 'StoreDir: /nix/store' <<<"$info" || die "nix-cache-info lacks StoreDir"
  grep -qx 'WantMassQuery: 1' <<<"$info" || die "nix-cache-info lacks WantMassQuery"
  grep -q '^Priority: [0-9]\+$' <<<"$info" || die "nix-cache-info lacks Priority"
  echo "nix-cache-info ok: $(tr '\n' ' ' <<<"$info")"

  # HEAD is what nix sends first; a cache that answers it with a body or a 405
  # costs a round trip per path.
  curl -fsS -I --max-time 10 "$url/nix-cache-info" >/dev/null || die "HEAD /nix-cache-info failed"
  echo "HEAD ok"

  # A miss is a 404 (that is how nix decides to build), a write is a 405.
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url/00000000000000000000000000000000.narinfo")"
  [ "$code" = "404" ] || die "expected 404 for a missing narinfo, got $code"
  code="$(curl -s -o /dev/null -w '%{http_code}' -X PUT --max-time 10 "$url/nix-cache-info")"
  [ "$code" = "405" ] || die "expected 405 for PUT, got $code"
  echo "miss=404 write=405 ok"

  if [ -n "${STORE_HASH:-}" ]; then
    narinfo="$(curl -fsS --max-time 10 "$url/$STORE_HASH.narinfo")" || die "no narinfo for $STORE_HASH"
    grep -q '^Sig: ' <<<"$narinfo" || die "narinfo for $STORE_HASH is unsigned"
    grep -q '^URL: nar/' <<<"$narinfo" || die "narinfo for $STORE_HASH names no nar"
    echo "narinfo ok: $(grep -m1 '^Sig: ' <<<"$narinfo" | cut -d: -f2- | cut -c1-40)…"
  fi
  ;;

size)
  # R2's free tier is the budget; there is no per-bucket quota to lean on, so the
  # number has to be measured. Exits 1 at the cap, so a fill loop stops itself.
  load_s3_env
  json="$(rclone size "r2:$BUCKET" --json)" || die "rclone could not size r2:$BUCKET"
  bytes="$(jq -r '.bytes' <<<"$json")"
  count="$(jq -r '.count' <<<"$json")"
  python3 - "$bytes" "$count" "$BUDGET_GIB" <<'PY'
import sys
bytes_, count, budget_gib = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
budget = budget_gib * 1024**3
pct = 100 * bytes_ / budget
print(f"nix-cache: {bytes_/1024**3:.2f} GiB of {budget_gib} GiB ({pct:.1f}%), {count} objects")
if bytes_ >= budget:
    sys.exit(f"nixcache: at or over the {budget_gib} GiB budget — gc the bucket before pushing")
if pct >= 90:
    print("nixcache: warning, past 90% of the budget", file=sys.stderr)
PY
  ;;

keygen)
  # One cache identity, generated once. The secret goes to sops so it is not a
  # file on one machine; the public half is what lib/cache-registry.nix carries.
  [ -n "${KEY_NAME:-}" ] || die "KEY_NAME=nix-cache-1 required (it is the prefix of every signature)"
  load_s3_env
  existing="$(sops -d --output-type json "$secrets" | jq -r "$SIGNING_KEY_PATH // \"\"")"
  [ -z "$existing" ] || die "sops already holds $SIGNING_KEY_PATH — refusing to rotate a live cache identity"
  secret_key="$(nix key generate-secret --key-name "$KEY_NAME")"
  public_key="$(printf '%s' "$secret_key" | nix key convert-secret-to-public)"
  sops set "$secrets" "$SIGNING_KEY_PATH" "\"$secret_key\""
  echo "secret stored in sops at $SIGNING_KEY_PATH"
  echo
  echo "public key (goes in lib/cache-registry.nix and every client's trusted-public-keys):"
  echo "  $public_key"
  echo
  echo "GitHub secret for the CI push (from a machine with gh auth):"
  echo "  sops -d --output-type json $secrets | jq -r '$SIGNING_KEY_PATH // \"\"' | gh secret set NIXCACHE_SIGNING_KEY"
  ;;

push)
  # A local write through the same path CI uses: S3 API, signed here, served by
  # the edge. The key is passed in NIX_CONFIG so it never appears in `ps`.
  target="${2:-}"
  [ -n "$target" ] || die "push <store-path> required"
  load_s3_env
  signing_key="$(sops -d --output-type json "$secrets" | jq -r "$SIGNING_KEY_PATH // \"\"")"
  [ -n "$signing_key" ] && [ "$signing_key" != null ] || die "no signing key in sops — run: task dev:nixcache:keygen KEY_NAME=…"
  keyfile="$(mktemp)"
  chmod 600 "$keyfile"
  trap 'rm -f "$keyfile"' EXIT
  printf '%s\n' "$signing_key" >"$keyfile"
  export AWS_ACCESS_KEY_ID="$RCLONE_CONFIG_R2_ACCESS_KEY_ID"
  export AWS_SECRET_ACCESS_KEY="$RCLONE_CONFIG_R2_SECRET_ACCESS_KEY"
  # `secret-key=` is the store's own signing parameter and its value is a PATH,
  # not the key. Setting `secret-key-files` in NIX_CONFIG instead writes narinfo
  # with no Sig: line at all (measured on Nix 2.35.3 against a file:// cache:
  # 0 signatures), which a client then rejects as unsigned.
  nix copy --to "s3://$BUCKET?endpoint=$(endpoint_url)&region=auto&compression=zstd&secret-key=$keyfile" "$target"
  echo "pushed $target to s3://$BUCKET"
  ;;

*)
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
  ;;
esac
