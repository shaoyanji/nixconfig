#!/usr/bin/env bash
# tailnet-policy.sh — keep the tailnet policy file in the repo, not in a console.
#
# Route approval is per device and dies when a node is re-keyed. The durable form
# is `autoApprovers` in the policy file — a device authenticated by an admin
# advertises the prefix and Tailscale approves it immediately, so adding a host
# stops being "remember to click Edit route settings".
#
#   tailnet-policy.sh            # semantic diff: repo file vs live tailnet (exit 1 on drift)
#   tailnet-policy.sh --apply    # POST the repo file (needs write scope; FORCE=1 for non-route edits)
#
# The diff is SEMANTIC, not textual: both sides are stripped of HuJSON comments
# and trailing commas and compared as sorted JSON, so a comment edit is not drift
# and a reordered list is not a change. What `--apply` sends is the repo file
# verbatim, comments included, because the console document is meant to be the
# readable copy.
#
# Applying replaces the WHOLE policy. Anything changed in the console and not
# mirrored here is reverted, which is why the default path refuses to touch
# anything except `.autoApprovers.routes` unless FORCE=1 is set.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
policy="$repo/modules/config/tailnet-policy.hujson"
# shellcheck source=lib/tailnet-api.sh
source "$here/lib/tailnet-api.sh"

mode="diff"
case "${1:-}" in
  "" | --diff) ;;
  --apply) mode="apply" ;;
  *)
    echo "tailnet-policy.sh: unknown argument '$1' (use --diff or --apply)" >&2
    exit 1
    ;;
esac

if [ ! -f "$policy" ]; then
  echo "tailnet-policy.sh: $policy is missing" >&2
  exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# HuJSON -> strict JSON: // and /* */ outside strings dropped, trailing commas
# removed. Kept here because the fleet has no hujson parser, and the comparison
# must not care about comments.
hujson_to_json() {
  python3 - "$1" >"$2" <<'PY'
import json, re, sys

src = open(sys.argv[1]).read()
out, i, n = [], 0, len(src)
while i < n:
    c = src[i]
    if c == '"':
        j = i + 1
        while j < n:
            if src[j] == "\\":
                j += 2
                continue
            if src[j] == '"':
                j += 1
                break
            j += 1
        out.append(src[i:j])
        i = j
        continue
    if src.startswith("//", i):
        k = src.find("\n", i)
        i = n if k < 0 else k
        continue
    if src.startswith("/*", i):
        k = src.find("*/", i + 2)
        i = n if k < 0 else k + 2
        continue
    out.append(c)
    i += 1
stripped = re.sub(r",(\s*[}\]])", r"\1", "".join(out))
try:
    doc = json.loads(stripped)
except json.JSONDecodeError as exc:
    sys.exit(f"{sys.argv[1]}: not valid HuJSON after comment stripping: {exc}")
print(json.dumps(doc, indent=2, sort_keys=True))
PY
}

hujson_to_json "$policy" "$work/repo.json" || { echo "tailnet-policy.sh: the repo policy file does not parse" >&2; exit 2; }

token="$(tailnet_token)" || exit 2
auth="Authorization: Bearer $token"

etag="$(curl -sS -m 20 -D "$work/hdr" -o "$work/live.hujson" -H "$auth" \
  "https://api.tailscale.com/api/v2/tailnet/-/acl" -w '%{http_code}' || true)"
if [ "$etag" != "200" ]; then
  echo "tailnet-policy.sh: could not read the live policy (HTTP $etag)" >&2
  head -c 300 "$work/live.hujson" >&2 || true
  exit 2
fi
live_etag="$(tr -d '\r' <"$work/hdr" | sed -n 's/^[Ee][Tt][Aa][Gg]: *//p' | head -1)"
hujson_to_json "$work/live.hujson" "$work/live.json" || { echo "tailnet-policy.sh: the live policy does not parse" >&2; exit 2; }

# Sorted JSON on both sides, so list order and formatting cannot fake a diff.
jq -S . "$work/live.json" >"$work/live.sorted"
jq -S . "$work/repo.json" >"$work/repo.sorted"

if diff -q "$work/live.sorted" "$work/repo.sorted" >/dev/null; then
  echo "in sync: the live tailnet policy matches modules/config/tailnet-policy.hujson"
  exit 0
fi

echo "DRIFT: live tailnet policy differs from the repo file"
diff -u --label "live" --label "repo" "$work/live.sorted" "$work/repo.sorted" || true

# Everything except .autoApprovers.routes must be identical for a default apply:
# route approval is what this tool is for, access rules are not.
jq -S 'del(.autoApprovers.routes)' "$work/live.json" >"$work/live.noroutes"
jq -S 'del(.autoApprovers.routes)' "$work/repo.json" >"$work/repo.noroutes"
if ! diff -q "$work/live.noroutes" "$work/repo.noroutes" >/dev/null; then
  echo
  echo "OUTSIDE autoApprovers.routes: this apply would change more than route approval"
  echo "(acls, ssh, nodeAttrs or the exitNode list). Review the diff above; re-run with"
  echo "FORCE=1 to accept it."
  [ "${FORCE:-}" = "1" ] || exit 1
fi

if [ "$mode" = "diff" ]; then
  echo
  echo "Apply with: task ops:tailnet:policy:apply"
  exit 1
fi

echo
echo "posting the repo policy ($(wc -l <"$policy") lines) to the tailnet"
args=(-sS -m 20 -o "$work/post.out" -w '%{http_code}' -X POST -H "$auth"
  -H 'Content-Type: application/json' --data-binary "@$policy")
[ -n "$live_etag" ] && args+=(-H "If-Match: $live_etag")
code="$(curl "${args[@]}" "https://api.tailscale.com/api/v2/tailnet/-/acl")"

case "$code" in
  200)
    echo "applied. autoApprovers now covers:"
    hujson_to_json "$work/post.out" "$work/post.json" 2>/dev/null \
      && jq -r '.autoApprovers.routes // {} | to_entries[] | "  \(.key)  <- \(.value | join(","))"' "$work/post.json" \
      || echo "  (response was not HuJSON; re-run the diff to confirm)"
    ;;
  403)
    echo "tailnet-policy.sh: HTTP 403 — the credential is read-only." >&2
    echo "  Needs the policy_file scope: an OAuth client or API key from the console's" >&2
    echo "  Trust credentials page, at TAILSCALE.CLIENT.* or TAILSCALE.API.KEY in sops." >&2
    head -c 300 "$work/post.out" >&2
    exit 1
    ;;
  412)
    echo "tailnet-policy.sh: HTTP 412 — the policy changed while this ran (ETag mismatch)." >&2
    echo "  Re-run the diff; someone edited the policy in the console." >&2
    exit 1
    ;;
  *)
    echo "tailnet-policy.sh: apply failed HTTP $code" >&2
    head -c 500 "$work/post.out" >&2
    exit 1
    ;;
esac
