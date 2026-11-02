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
# Two planes, two homes: Cloudflare API/R2 credentials are third-party keys
# (apikeys.yaml), while the cache signing key is a fleet secret and sits beside
# harmonia's at top level in secrets.yaml — the same shape, one cache per key.
secrets="$repo/modules/secrets/apikeys.yaml"
fleet_secrets="$repo/modules/secrets/secrets.yaml"

BUCKET="nix-cache"
BUDGET_GIB="${BUDGET_GIB:-10}"
# Two spellings of one path: `sops set` takes the bare bracket form, jq needs the
# leading dot to treat it as an index rather than an array literal.
SIGNING_KEY_SOPS='["nix_cache_edge_signing_key"]'
SIGNING_KEY_JQ=".$SIGNING_KEY_SOPS"

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
# CI has no sops and no age key, so every value can also arrive by environment —
# the same three names, prefixed NIXCACHE_R2_.
load_s3_env() {
  export RCLONE_CONFIG_R2_TYPE=s3
  export RCLONE_CONFIG_R2_PROVIDER=Cloudflare
  if [ -n "${NIXCACHE_R2_ACCESS_KEY_ID:-}" ]; then
    export RCLONE_CONFIG_R2_ACCESS_KEY_ID="$NIXCACHE_R2_ACCESS_KEY_ID"
    export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$NIXCACHE_R2_SECRET_ACCESS_KEY"
    export RCLONE_CONFIG_R2_ENDPOINT="$NIXCACHE_R2_ENDPOINT"
    return 0
  fi
  need_secrets
  export RCLONE_CONFIG_R2_ACCESS_KEY_ID="$(secret '.["CLOUDFLARE"]["ACCESS"]["KEY"]["ID"]')"
  export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$(secret '.["CLOUDFLARE"]["SECRET"]["ACCESS"]["KEY"]')"
  export RCLONE_CONFIG_R2_ENDPOINT="$(secret '.["CLOUDFLARE"]["S3"]["API"]["ENDPOINT"]')"
}

# The signing key has the same two homes: sops locally, a repository secret in CI.
signing_key() {
  if [ -n "${NIXCACHE_SIGNING_KEY:-}" ]; then
    printf '%s\n' "$NIXCACHE_SIGNING_KEY"
    return 0
  fi
  [ -f "$fleet_secrets" ] || die "$fleet_secrets missing (is the modules/secrets submodule checked out?)"
  sops -d --output-type json "$fleet_secrets" | jq -r "$SIGNING_KEY_JQ // \"\""
}

endpoint_url() {
  secret '.["CLOUDFLARE"]["S3"]["API"]["ENDPOINT"]'
}

# An empty bucket is not an error: rclone exits 3 with "directory not found" until
# the first object exists, and a budget check must read that as zero bytes.
bucket_bytes() {
  local out
  out="$(rclone size "r2:$BUCKET" --json 2>/dev/null || true)"
  if [ -z "$out" ]; then
    echo 0
    return 0
  fi
  jq -r '.bytes // 0' <<<"$out"
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
  # Positional, not env: `URL=…` on a task line is a task variable and never
  # reaches this process (measured twice while building this).
  url="${URL:-${2:-}}"
  store_hash="${STORE_HASH:-${3:-}}"
  [ -n "$url" ] || die "task checks:nixcache:probe -- <url> [store-hash] required"
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

  if [ -n "$store_hash" ]; then
    narinfo="$(curl -fsS --max-time 10 "$url/$store_hash.narinfo")" || die "no narinfo for $store_hash"
    grep -q '^Sig: ' <<<"$narinfo" || die "narinfo for $store_hash is unsigned"
    grep -q '^URL: nar/' <<<"$narinfo" || die "narinfo for $store_hash names no nar"
    echo "narinfo ok: $(grep -m1 '^Sig: ' <<<"$narinfo" | cut -d: -f2- | cut -c1-40)…"
  fi
  ;;

size)
  # R2's free tier is the budget and there is no per-bucket quota to lean on, so
  # the number is measured: this is the reading `push` refuses on.
  budget_gib="${BUDGET_GIB:-${2:-10}}"
  load_s3_env
  json="$(rclone size "r2:$BUCKET" --json 2>/dev/null || true)"
  bytes="$(bucket_bytes)"
  count="$(jq -r '.count // 0' <<<"${json:-{\}}")"
  python3 - "$bytes" "$count" "$budget_gib" <<'PY'
import sys
bytes_, count, budget_gib = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
budget = budget_gib * 1024**3
pct = 100 * bytes_ / budget
print(f"nix-cache: {bytes_/1024**3:.2f} GiB of {budget_gib} GiB ({pct:.1f}%), {count} objects")
if bytes_ >= budget:
    sys.exit(f"nixcache: at or over the {budget_gib} GiB budget — gc the bucket before pushing")
PY
  ;;

keygen)
  # One cache identity, generated once. The secret goes to sops so it is not a
  # file on one machine; the public half is what lib/cache-registry.nix carries.
  # Positional so `task dev:nixcache:keygen -- delphi.edge-1` works: a bare
  # KEY_NAME=… on the task line is a task variable and never reaches this env.
  key_name="${KEY_NAME:-${2:-}}"
  [ -n "$key_name" ] || die "task dev:nixcache:keygen -- <name> required (the name prefixes every signature)"
  load_s3_env
  existing="$(sops -d --output-type json "$fleet_secrets" | jq -r "$SIGNING_KEY_JQ // \"\"")"
  [ -z "$existing" ] || die "sops already holds $SIGNING_KEY_SOPS — refusing to rotate a live cache identity"
  secret_key="$(nix key generate-secret --key-name "$key_name")"
  public_key="$(printf '%s' "$secret_key" | nix key convert-secret-to-public)"
  sops set "$fleet_secrets" "$SIGNING_KEY_SOPS" "\"$secret_key\""
  echo "secret stored in sops at $SIGNING_KEY_SOPS"
  echo
  echo "public key (goes in lib/cache-registry.nix and every client's trusted-public-keys):"
  echo "  $public_key"
  echo
  echo "GitHub secret for the CI push (from a machine with gh auth):"
  echo "  sops -d --output-type json $fleet_secrets | jq -r '$SIGNING_KEY_JQ' | gh secret set NIXCACHE_SIGNING_KEY"
  ;;

push)
  # The buffer rule, in one place: a path that cachix or cache.nixos.org already
  # serves is not uploaded — the bucket exists for what those two cannot hold.
  # Then the budget is a hard refusal, not a warning: R2 bills storage and the
  # free tier is the limit this bucket was sized against.
  shift
  [ "$#" -gt 0 ] || die "task dev:nixcache:push -- <store-path|attr> [...] required"
  load_s3_env

  # Addresses come from the registry, the one home for them (flake output, no eval
  # of a host). CI has no sops, so every credential still arrives by environment.
  cache_url() { nix eval --raw ".#cacheRegistry.caches.$1.url"; }
  CACHIX="${CACHIX_URL:-$(cache_url cachix)}"
  NIXOS="${NIXOS_URL:-$(cache_url nixos)}"
  EDGE="${EDGE_URL:-$(cache_url edge)}"

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  # The closure, with nar sizes: what could be pushed and what it would cost.
  nix path-info --recursive --json "$@" >"$tmp/closure.json"
  jq -r 'to_entries[] | "\(.key)\t\(.value.narSize // 0)"' "$tmp/closure.json" >"$tmp/all.tsv"

  # One HEAD per path per cache, 16 at a time. A path present anywhere public is
  # dropped before nix copy ever sees it.
  check_public() {
    local path="$1" hash
    hash="$(basename "$path")"
    hash="${hash:0:32}"
    local base
    for base in "$CACHIX" "$NIXOS" "$EDGE"; do
      if curl -sfI --max-time 5 --retry 0 -o /dev/null "${base%/}/$hash.narinfo"; then
        return 0
      fi
    done
    return 1
  }
  export -f check_public
  export CACHIX NIXOS EDGE
  cut -f1 "$tmp/all.tsv" | xargs -r -P 16 -I{} bash -c 'check_public "$@" || echo "$@"' _ {} >"$tmp/missing.txt"

  total="$(wc -l <"$tmp/all.tsv")"
  if [ ! -s "$tmp/missing.txt" ]; then
    echo "nixcache: nothing to push — all $total path(s) are already on cachix, cache.nixos.org or the bucket"
    exit 0
  fi
  # Join on the exact path field: `grep -x` would compare against "path<TAB>size"
  # and match nothing, which is how the first draft reported a 0-byte push.
  need="$(awk -F'\t' 'NR==FNR {keep[$0]; next} ($1 in keep) {sum += $2} END {print sum+0}' \
    "$tmp/missing.txt" "$tmp/all.tsv")"
  count="$(wc -l <"$tmp/missing.txt")"

  current="$(bucket_bytes)"
  python3 - "$current" "$need" "$BUDGET_GIB" "$count" "$total" <<'PY'
import sys
current, need, budget_gib, count, total = (int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5]))
budget = budget_gib * 1024**3
after = current + need
print(f"nixcache: {count}/{total} path(s) are unique to this cache; "
      f"{need/1024**2:.1f} MiB new, bucket after push {after/1024**3:.2f}/{budget_gib} GiB")
if after > budget:
    sys.exit(f"nixcache: refusing the push — it would take the bucket {after/1024**3:.2f} GiB over the "
             f"{budget_gib} GiB limit by {(after-budget)/1024**2:.1f} MiB; gc first")
PY

  sk="$(signing_key)"
  [ -n "$sk" ] || die "no signing key — run: task dev:nixcache:keygen -- <name>, or set NIXCACHE_SIGNING_KEY"
  keyfile="$tmp/signing-key"
  printf '%s\n' "$sk" >"$keyfile"
  chmod 600 "$keyfile"
  export AWS_ACCESS_KEY_ID="$RCLONE_CONFIG_R2_ACCESS_KEY_ID"
  export AWS_SECRET_ACCESS_KEY="$RCLONE_CONFIG_R2_SECRET_ACCESS_KEY"
  # `secret-key=` is the store's own signing parameter and its value is a PATH,
  # not the key. Setting `secret-key-files` in NIX_CONFIG instead writes narinfo
  # with no Sig: line at all (measured on Nix 2.35.3 against a file:// cache:
  # 0 signatures), which a client then rejects as unsigned.
  # Signed into a local staging cache, then uploaded with rclone. Three measured
  # facts (2026-11-02) are why:
  #
  # 1. `nix copy` walks references by default: a two-path push uploaded all 342 of
  #    their neighbours, 340 of which a public cache already served.
  # 2. `--no-recursive` alone fails — "cannot add X because the reference Y is not
  #    valid" — because a binary cache refuses a narinfo whose references it does
  #    not have. The stubs below satisfy that check without ever being uploaded:
  #    each unique path is written with its real signed narinfo, its own nar, and
  #    nothing else, while its references stay wherever they already are.
  # 3. `nix copy --to s3://…` against a freshly recreated R2 bucket exits 0 having
  #    written nothing at all. Staging makes the write observable.
  stage="$tmp/stage"
  mkdir -p "$stage"
  while read -r path; do
    nix path-info --json "$path" | jq -r '.[].references[]'
  done <"$tmp/missing.txt" | sort -u >"$tmp/refs.txt"
  # The stub has to parse: nix reads a reference's narinfo to call it valid, and a
  # bare StorePath line fails with "NarHash missing". These are never uploaded.
  # A stub for a path we are about to push would be mistaken for a finished
  # narinfo and skip the real signed write, so unique paths are excluded here.
  grep -vxF -f "$tmp/missing.txt" "$tmp/refs.txt" >"$tmp/refs-stub.txt" || true
  # A reference-free closure is the common case for a runCommand, and `jq -s add`
  # over empty input is null — which is how a one-path push died on `to_entries`.
  if [ -s "$tmp/refs-stub.txt" ]; then
    xargs -a "$tmp/refs-stub.txt" -r -n 100 nix path-info --json 2>/dev/null |
      jq -s 'add // {}' >"$tmp/refs.json"
    jq -r 'to_entries[] | "\(.key)\t\(.value.narHash)\t\(.value.narSize)"' "$tmp/refs.json" |
      while IFS=$'\t' read -r ref nar_hash nar_size; do
        name="${ref##*/}"
        printf 'StorePath: %s\nURL: nar/%s.nar\nCompression: none\nNarHash: sha256:%s\nNarSize: %s\n' \
          "$ref" "${name:0:32}" "${nar_hash#sha256-}" "$nar_size" >"$stage/${name:0:32}.narinfo"
      done
  fi
  # shellcheck disable=SC2046 # one argument per line, store paths never contain spaces
  nix copy --no-recursive --to "file://$stage?secret-key=$keyfile" $(cat "$tmp/missing.txt")

  # Only the unique paths leave this machine; the stubs are scaffolding.
  mkdir -p "$tmp/up"
  while read -r path; do
    name="${path##*/}"
    hash="${name:0:32}"
    narinfo="$stage/$hash.narinfo"
    [ -f "$narinfo" ] || die "staged nothing for $path"
    grep -q '^Sig: ' "$narinfo" || die "$path staged an unsigned narinfo — check $SIGNING_KEY_SOPS"
    grep -q '^NarHash: ' "$narinfo" || die "$path staged a stub, not a real narinfo"
    cp "$narinfo" "$tmp/up/"
    nar="$(grep -m1 '^URL: ' "$narinfo" | cut -d' ' -f2)"
    mkdir -p "$tmp/up/$(dirname "$nar")"
    cp "$stage/$nar" "$tmp/up/$nar"
  done <"$tmp/missing.txt"

  rclone copy "$tmp/up" "r2:$BUCKET" --transfers 8 --checkers 16

  # A push that cannot be read back is not a push. One HEAD through the public
  # edge, which also proves the Worker's binding sees the same bucket.
  first_hash="$(head -1 "$tmp/missing.txt" | xargs -I{} basename {} | cut -c1-32)"
  curl -sfI --max-time 10 -o /dev/null "${EDGE%/}/$first_hash.narinfo" ||
    die "uploaded, but $EDGE/$first_hash.narinfo is not served"
  echo "pushed $count path(s); readable at $EDGE; bucket now $(bucket_bytes | python3 -c 'import sys; print(f"{int(sys.stdin.read())/1024**3:.2f} GiB")')"
  ;;

*)
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
  ;;
esac
