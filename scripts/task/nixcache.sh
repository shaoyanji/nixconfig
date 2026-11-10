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
. "${BASH_SOURCE[0]%/*}/lib/paths.sh"
secrets=$(apikeys_file)
fleet_secrets=$(secret_file)

BUCKET="nix-cache"
BUDGET_GIB="${BUDGET_GIB:-10}"
# The two axes of holding space. RETENTION_DAYS is the R2 lifecycle backstop —
# objects whose upload is older than this disappear without anyone running
# anything. GC_TRIGGER/TARGET is cachix's shape (delete the oldest until under a
# target) and needs a script, because R2 has no last-access clock to read.
#
# The backstop is deliberately longer than cachix's 90 days, because here it is
# not the collector: `gc` frees space by size, and an expiry that fires first
# deletes on age without knowing what a host still substitutes from. A year is
# the point at which "nobody re-pushed this" is a fact about the path rather
# than about the calendar.
RETENTION_DAYS="${RETENTION_DAYS:-365}"
GC_TRIGGER_PERCENT="${GC_TRIGGER_PERCENT:-90}"
GC_TARGET_PERCENT="${GC_TARGET_PERCENT:-75}"
GC_LIMIT="${GC_LIMIT:-50}"
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

  # The lifecycle rule is the part that costs nothing to run: one rule for the
  # whole bucket, because a narinfo and its nar are written in the same second and
  # must expire in the same second. Left to drift they break a pair — a narinfo
  # whose nar is gone is a hard client failure, where a missing narinfo is only a
  # cache miss. Applied here so the rule is a property of the bucket, not of a
  # dashboard visit.
  # Reconcile, do not just create: a rule left at an older `RETENTION_DAYS` is
  # drift the dashboard hides, and `add --force` on its own would never report it.
  # The listing prints `action:   Expire objects after <n> days`, so the number is
  # the fifth field of the first line that names the action.
  current_days="$(wrangler r2 bucket lifecycle list "$BUCKET" 2>/dev/null |
    awk '/Expire objects after/ {print $5; exit}')"
  if [ "$current_days" != "$RETENTION_DAYS" ]; then
    [ -n "$current_days" ] && wrangler r2 bucket lifecycle remove "$BUCKET" --name expire-buffer
    wrangler r2 bucket lifecycle add "$BUCKET" expire-buffer --expire-days "$RETENTION_DAYS" --force
  fi
  wrangler r2 bucket lifecycle list "$BUCKET"

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

gc)
  # Cachix's algorithm, as far as R2 allows: sort by age, delete the oldest until
  # the store is back under target. Cachix sorts by *last access* and can, because
  # it sees every request; this Worker cannot — a narinfo is served
  # `Cache-Control: immutable`, so Cloudflare answers the repeats and the origin
  # only ever observes misses. Upload age is the honest stand-in, and it
  # self-corrects: a path a build still needs is re-pushed, which refreshes it.
  #
  # Dry run unless --delete. Sizes come from one listing, so the plan is complete
  # before the first delete.
  delete=0
  [ "${2:-}" = "--delete" ] && delete=1
  load_s3_env

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  rclone lsjson "r2:$BUCKET" --files-only --recursive >"$tmp/objects.json"

  python3 - "$tmp/objects.json" "$BUCKET" "$BUDGET_GIB" "$GC_TRIGGER_PERCENT" "$GC_TARGET_PERCENT" "$GC_LIMIT" "$tmp" <<'PY'
import json, subprocess, sys, datetime
objects, bucket, budget_gib, trigger, target, limit, tmp = (
    json.load(open(sys.argv[1])), sys.argv[2], int(sys.argv[3]), int(sys.argv[4]),
    int(sys.argv[5]), int(sys.argv[6]), sys.argv[7])
budget = budget_gib * 1024**3
by_name = {o["Path"]: o for o in objects}
total = sum(o["Size"] for o in objects)
print(f"nix-cache: {total/1024**3:.2f} GiB held, trigger at {trigger}%, target {target}%")
if total < budget * trigger / 100:
    print("nix-cache: under the trigger, nothing to collect")
    sys.exit(0)

now = datetime.datetime.now(datetime.timezone.utc)
def age_days(o):
    return (now - datetime.datetime.fromisoformat(o["ModTime"].replace("Z", "+00:00"))).days

narinfos = sorted((o for o in objects if o["Path"].endswith(".narinfo")), key=lambda o: o["ModTime"])
freed, chosen = 0, []
for narinfo in narinfos:
    if total - freed <= budget * target / 100:
        break
    if len(chosen) >= limit:
        print(f"nix-cache: stopping at the {limit}-path per-run limit — run again for more")
        break
    path = narinfo["Path"].removesuffix(".narinfo")
    chosen.append({"hash": path, "age": age_days(narinfo), "narinfo": narinfo["Path"]})
    freed += narinfo["Size"]
    # The nar is found from the narinfo body, never guessed: its name is the file
    # hash, not the store hash.
    body = subprocess.run(
        ["rclone", "cat", f"r2:{bucket}/" + narinfo["Path"]], capture_output=True, text=True).stdout
    nar = next((line.split(": ", 1)[1].strip() for line in body.splitlines() if line.startswith("URL: ")), None)
    if nar and nar in by_name:
        freed += by_name[nar]["Size"]
        chosen[-1]["nar"] = nar

if not chosen:
    print("nix-cache: nothing selected")
    sys.exit(0)

print(f"nix-cache: {len(chosen)} path(s) free {freed/1024**2:.1f} MiB, oldest {chosen[0]['age']}d")
for entry in chosen:
    print(f"  {entry['age']:>4}d  {entry['hash']}  nar={'yes' if entry.get('nar') else 'missing'}")
with open(tmp + "/delete.txt", "w") as handle:
    for entry in chosen:
        handle.write(entry["narinfo"] + "\n")
        if entry.get("nar"):
            handle.write(entry["nar"] + "\n")
PY

  [ -s "$tmp/delete.txt" ] || exit 0
  if [ "$delete" = "0" ]; then
    echo "nix-cache: dry run — pass --delete to remove these"
    exit 0
  fi
  # Pairs only: a narinfo is deleted with its nar, never alone, in both directions.
  while read -r object; do
    rclone deletefile "r2:$BUCKET/$object"
  done <"$tmp/delete.txt"
  echo "nix-cache: deleted $(wc -l <"$tmp/delete.txt") object(s); bucket now $(bucket_bytes | python3 -c 'import sys; print(f"{int(sys.stdin.read())/1024**3:.2f} GiB")')"
  ;;

sync)
  # The monthly handoff, one host at a time: build what the fleet needs on the
  # machine that should build it, then let `push` apply the three rules. Routing,
  # not caching — the rules stay in one place.
  #
  # Arch decides the builder, and the choice is about the *inputs*, not the output:
  # a natively built path is the same bytes either way (the drv content-addresses
  # it), but on the arch that owns the official caches those inputs are already
  # local, so the unique delta this bucket exists for is what actually gets built.
  # That is why delphi compiles aarch64 (itself and minyx) and x86_64 goes to a
  # configured remote builder instead of a 2-OCPU ARM box.
  shift
  hosts=()
  dry=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
    --hosts)
      # shellcheck disable=SC2206 # a comma list on purpose, so task CLI_ARGS stays one word
      hosts=(${2//,/ })
      shift
      ;;
    --dry-run) dry=1 ;;
    *) die "sync: unknown argument $1" ;;
    esac
    shift
  done

  export NIX_CONFIG="experimental-features = nix-command flakes pipe-operators${NIX_CONFIG:+ $NIX_CONFIG}"
  current="$(nix eval --raw --impure --expr builtins.currentSystem)"
  if [ "${#hosts[@]}" -eq 0 ]; then
    mapfile -t hosts < <(nix eval --json '.#inventory.hosts' |
      jq -r 'to_entries[] | select(.value.kind == "nixos" and .value.status == "active") | .key')
  fi
  echo "nixcache: sync on $current — ${#hosts[@]} host(s)"

  failed=0
  for host in "${hosts[@]}"; do
    arch="$(nix eval --raw ".#inventory.hosts.$host.arch" 2>/dev/null || echo unknown)"
    attr=".?submodules=1#nixosConfigurations.$host.config.system.build.toplevel"
    route=()
    where="native"
    if [ "$arch" != "$current" ]; then
      # `--max-jobs 0` is "offload or fail": compiling an x86_64 closure locally is
      # the mistake, and /etc/nix/machines is where the answer lives.
      route=(--max-jobs 0)
      where="remote builders"
      if [ ! -s /etc/nix/machines ]; then
        echo "  $host ($arch): SKIPPED — no /etc/nix/machines here; build it on CI or a host that has one"
        continue
      fi
    fi
    if [ "$dry" = 1 ]; then
      echo "  $host ($arch): would build $where, then push its delta"
      continue
    fi
    # Deliberate build, never a check: this is the job the schedule exists for.
    if ! out="$(nix build --no-link --print-out-paths "${route[@]}" "$attr" 2>/dev/null)"; then
      echo "  $host ($arch): BUILD FAILED"
      failed=1
      continue
    fi
    # push owns dedupe, the budget refusal and the read-back. Its refusal is the
    # signal to collect, not a bug.
    # No `tail`: under the monthly unit the journal is the log, and a buffered
    # pipe is how the first real run looked silent while it was uploading.
    if bash "$0" push "$out" 2>&1 | sed 's/^/    /'; then
      echo "  $host ($arch): pushed"
    else
      echo "  $host ($arch): PUSH REFUSED (budget) — run: task dev:nixcache:gc -- --delete"
      failed=1
    fi
  done
  exit "$failed"
  ;;

fleet)
  # The enablement check a cache needs once: is the edge actually in every host's
  # substituter list, in the right place, with the key clients verify against? The
  # compiled policy answers for every host in 0.2 s; one host eval then proves the
  # policy reaches `config.nix.settings` rather than sitting in an output nobody
  # reads.
  edge_url="$(nix eval --raw '.#cacheRegistry.caches.edge.url')"
  edge_key="$(nix eval --raw '.#cacheRegistry.caches.edge.key')"
  nix eval --json '.#inventory.hosts' >"${TMPDIR:-/tmp}/nixcache-fleet-hosts.json"
  nix eval --json '.#inventory.cache' >"${TMPDIR:-/tmp}/nixcache-fleet-cache.json"
  python3 - "$edge_url" "$edge_key" <<'PY'
import json, os, sys
edge, key = sys.argv[1], sys.argv[2]
tmp = os.environ.get("TMPDIR", "/tmp")
hosts = json.load(open(f"{tmp}/nixcache-fleet-hosts.json"))
cache = json.load(open(f"{tmp}/nixcache-fleet-cache.json"))
bad = []
for name, host in sorted(hosts.items()):
    if host.get("kind") != "nixos" or host.get("status") != "active":
        continue
    policy = cache.get(name, {})
    subs = policy.get("substituters") or []
    if edge not in subs:
        bad.append(f"{name}: edge missing from substituters")
        continue
    if key not in (policy.get("trustedKeys") or []):
        bad.append(f"{name}: edge key not trusted")
    if "cachix" in str(subs) and subs.index(edge) < next(
            (i for i, u in enumerate(subs) if "cachix.org" in u), 99):
        bad.append(f"{name}: edge is ordered before cachix")
print(f"fleet: {len(bad)} problem(s) across the active NixOS hosts")
for line in bad:
    print("  " + line)
sys.exit(1 if bad else 0)
PY
  fleet_rc=$?

  # One host eval: the policy is only real if it lands in the setting.
  eff="$(nix eval --json '.?submodules=1#nixosConfigurations.delphi.config.nix.settings.substituters' 2>/dev/null || echo '[]')"
  if grep -qF "$edge_url" <<<"$eff"; then
    echo "wiring: delphi's nix.settings.substituters carries the edge (host eval)"
  else
    echo "wiring: delphi's nix.settings.substituters does NOT carry the edge" >&2
    fleet_rc=1
  fi

  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "${edge_url%/}/nix-cache-info")"
  [ "$code" = "200" ] && echo "live: $edge_url answers /nix-cache-info 200" || {
    echo "live: $edge_url answered $code" >&2
    fleet_rc=1
  }
  exit "$fleet_rc"
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
  EDGE="${EDGE_URL:-$(cache_url edge)}"

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  # The dedupe list IS the registry, not a hardcoded triple: every substituter a
  # host already asks answers first. Measured on delphi 2026-11-02, over its
  # 2728-path / 18.48 GiB system closure, of 2.39 GiB missing from cachix and
  # cache.nixos.org — 1.40 GiB (27 paths, the llm-agents tools: dsh, freebuff,
  # antigravity-cli, hermes) is on cache.numtide.com and 135 MiB (11 paths) on
  # nix-community. Asking all of them leaves 771 MiB / 365 paths genuinely
  # unique, so a 10 GiB bucket holds ~13 systems instead of ~4.
  #
  # LAN caches (harmonia) are excluded on purpose, and that is a policy, not an
  # oversight: a path only on harmonia is invisible to a WAN host, so skipping
  # it here would starve the edge of exactly what makes it worth having.
  #
  # Ordered by hit rate, not by substitution preference: cache.nixos.org answers
  # for ~79 % of a system closure (2158/2728), so asking it first costs most paths
  # one HEAD instead of four. The list is still the registry's — only the order it
  # is *asked* in changes, and the report still names the cache that had it.
  nix eval --json '.#cacheRegistry.caches' |
    jq -r '[to_entries[] | select(.value.role != "lan")]
           | sort_by(if .key == "nixos" then 0 else 1 end) | .[]
           | .value.url | rtrimstr("/")' >"$tmp/public.txt"

  # The closure, with nar sizes: what could be pushed and what it would cost.
  nix path-info --recursive --json "$@" >"$tmp/closure.json"
  jq -r 'to_entries[] | "\(.key)\t\(.value.narSize // 0)"' "$tmp/closure.json" >"$tmp/all.tsv"

  # One HEAD per path per cache, 16 at a time, in registry order so a hit names
  # the cheapest substituter that already has it. A path found anywhere is
  # dropped before nix copy ever sees it.
  check_public() {
    local path="$1" hash base
    hash="$(basename "$path")"
    hash="${hash:0:32}"
    while read -r base; do
      if curl -sfI --max-time 5 --retry 0 -o /dev/null "$base/$hash.narinfo"; then
        printf '%s\t%s\n' "$path" "$base"
        return 0
      fi
    done <"$tmp/public.txt"
    printf '%s\tMISS\n' "$path"
  }
  export -f check_public
  export tmp
  # 32 at a time: a HEAD costs a round trip, and the fleet's own paths are the
  # ones that fail every cache (measured 2026-11-02: 2728 paths in ~65 s at 32).
  cut -f1 "$tmp/all.tsv" | xargs -r -P 32 -I{} bash -c 'check_public "$@"' _ {} >"$tmp/where.tsv"
  awk -F'\t' '$2 == "MISS" {print $1}' "$tmp/where.tsv" >"$tmp/missing.txt"

  total="$(wc -l <"$tmp/all.tsv")"
  # The report is the argument for the whole exercise: it says which substituter
  # absorbed how many paths, so a push that uploads almost nothing demonstrates
  # why instead of looking broken.
  awk -F'\t' '$2 != "MISS" {count[$2]++} END {for (base in count) printf "  %5d already on %s\n", count[base], base}' \
    "$tmp/where.tsv" | sort -k4
  if [ ! -s "$tmp/missing.txt" ]; then
    echo "nixcache: nothing to push — all $total path(s) are served by $(wc -l <"$tmp/public.txt") substituter(s)"
    exit 0
  fi
  # Join on the exact path field: `grep -x` would compare against "path<TAB>size"
  # and match nothing, which is how the first draft reported a 0-byte push.
  count="$(wc -l <"$tmp/missing.txt")"

  current="$(bucket_bytes)"
  # The survivors by size, largest first: a refusal has to name the path that
  # caused it. A NixOS system closure is ~18 GiB, of which under 1 GiB is unique
  # to the fleet (measured on delphi 2026-11-02), so what lands here is decided by
  # a handful of paths — a 334 MiB stirling-pdf tree matters more than 300 tiny
  # ones.
  awk -F'\t' 'NR==FNR {keep[$0]; next} ($1 in keep)' "$tmp/missing.txt" "$tmp/all.tsv" |
    sort -t$'\t' -k2 -nr >"$tmp/need.tsv"
  python3 - "$current" "$BUDGET_GIB" "$count" "$total" "$tmp/need.tsv" <<'PY'
import sys
current, budget_gib, count, total, needfile = (
    int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5])
budget = budget_gib * 1024**3
rows = [line.rstrip("\n").split("\t") for line in open(needfile) if "\t" in line]
need = sum(int(size or 0) for _, size in rows)
after = current + need
print(f"nixcache: {count}/{total} path(s) are unique to this cache; "
      f"{need/1024**2:.1f} MiB new, bucket after push {after/1024**3:.2f}/{budget_gib} GiB")
for path, size in rows[:5]:
    size = int(size or 0)
    print(f"  {size/1024**2:>7.0f} MiB  {path}")
if len(rows) > 5:
    rest = sum(int(size or 0) for _, size in rows[5:])
    print(f"  {rest/1024**2:>7.0f} MiB  ({len(rows) - 5} more)")
if after > budget:
    over = f"{after/1024**3:.2f} GiB over the {budget_gib} GiB limit by {(after-budget)/1024**2:.1f} MiB"
    # A single path bigger than the whole budget can never land here, however
    # often gc runs. Say that plainly instead of reporting an arithmetic overrun.
    biggest, biggest_path = (int(rows[0][1] or 0), rows[0][0]) if rows else (0, "")
    if biggest > budget:
        sys.exit(f"nixcache: refusing the push — {biggest_path} alone is "
                 f"{biggest/1024**3:.2f} GiB, more than the whole {budget_gib} GiB budget")
    sys.exit(f"nixcache: refusing the push — it would take the bucket {over}; gc first")
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
