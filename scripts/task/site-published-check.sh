#!/usr/bin/env bash
# site-published-check.sh — the live page must be the build origin/main makes.
#
# `checks:site:path` asks a vhost which store path it *says* it serves, which
# needs a header the server sets. A Pages deploy leaves no header, no
# generation, no journal and no socket: a deploy that finished, a deploy that
# kept yesterday's tree and a deploy of another branch all answer 200. So this
# asks the only question Pages can answer — whether the bytes are the build.
#
# Both references are exact, and no build budget is spent here:
#   * This tree's `.#ATTR.outPath` against the same attr evaluated at BASE
#     (`git+file://<repo>?rev=<sha>`). A tree that is not BASE's build fails
#     before any request, so a pass proves main and not just a copy.
#   * What BASE builds against what HOST serves, file for file: Pages' `.html`
#     -> trailing-slash 308 is followed, and `_headers` is skipped because
#     Pages consumes it rather than serving it.
#
# The DNS pin is `site-check.sh`'s: this fleet's local resolver keeps a cached
# NXDOMAIN for a hostname added to Cloudflare the same day, which makes a
# healthy site look dead.
#
# Usage: site-published-check.sh
#   HOST=matt.bountystash.com ATTR=sites.matt-site BASE=origin/main
#
# EXIT
#   0  every file the build carries is served, byte for byte
#   1  divergence: this tree is not BASE's build, or a served file differs
#   2  cannot tell: no A record, no build here, an eval failed, no answer in time
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2

HOST=${HOST:-matt.bountystash.com}
ATTR=${ATTR:-sites.matt-site}
BASE=${BASE:-origin/main}
TIMEOUT=${TIMEOUT:-25}
EVAL_TIMEOUT=${EVAL_TIMEOUT:-180}
DEPLOY=${DEPLOY:-task matt:deploy:prod}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "site-published: $*" >&2
  exit 2
}

repo=$(git rev-parse --show-toplevel 2>/dev/null) || fail "not inside a git checkout"
base_sha=$(git rev-parse --verify --quiet "$BASE^{commit}") || fail "$BASE does not name a commit"

eval_out() { # REF LABEL -> outPath on stdout
  timeout "$EVAL_TIMEOUT" nix eval --raw "$1#${ATTR}.outPath" 2>"$tmp/$2.err"
}

tree_out=$(eval_out . tree) || {
  sed 's/^/  /' "$tmp/tree.err" >&2
  fail "could not evaluate .#${ATTR}.outPath in this tree"
}
[ -n "$tree_out" ] || fail ".#${ATTR}.outPath evaluated to an empty string"

main_out=$(eval_out "git+file://$repo?rev=$base_sha" main) || {
  sed 's/^/  /' "$tmp/main.err" >&2
  fail "could not evaluate ${ATTR} at $(git rev-parse --short "$base_sha")"
}
[ -n "$main_out" ] || fail "${ATTR} at $(git rev-parse --short "$base_sha") evaluated to an empty string"

if [ "$tree_out" != "$main_out" ]; then
  echo "FAIL this tree is not what ${BASE} builds" >&2
  echo "     tree: $tree_out" >&2
  echo "     ${BASE} $(git rev-parse --short "$base_sha"): $main_out" >&2
  echo "     fix:  run this at ${BASE}, or publish the build of ${BASE}" >&2
  exit 1
fi
echo "ok   ${ATTR} is the same build here and at ${BASE} $(git rev-parse --short "$base_sha")"

# The eval resolves a path without building it, so an unbuilt tree is a "cannot
# tell" and not a divergence — and this gate never compiles to find out.
[ -d "$main_out" ] || fail "$main_out is not built here — build ${ATTR} first (a gate spends no build budget)"

ip=$(dig +short @1.1.1.1 "$HOST" | grep -E '^[0-9]' | sed -n 1p)
[ -n "$ip" ] || fail "1.1.1.1 returns no A record for $HOST"

ok=0
bad=0
total=0
while IFS= read -r rel; do
  # Pages reads `_headers` at deploy time and never serves it.
  [ "$rel" = "_headers" ] && continue
  total=$((total + 1))
  case $rel in
    index.html) url=/ ;;
    */index.html) url="/${rel%/index.html}/" ;;
    *) url="/$rel" ;;
  esac
  code=$(curl -sSL --max-time "$TIMEOUT" --resolve "$HOST:443:$ip" \
    -o "$tmp/body" -w '%{http_code}' "https://$HOST$url")
  if [ "$code" != 200 ]; then
    printf 'FAIL %s%s answers %s, the build carries it\n' "$HOST" "$url" "$code"
    bad=$((bad + 1))
    continue
  fi
  if cmp -s "$tmp/body" "$main_out/$rel"; then
    printf 'ok   %s%s\n' "$HOST" "$url"
    ok=$((ok + 1))
  else
    printf 'FAIL %s%s differs  live %s %sB  build %s %sB\n' "$HOST" "$url" \
      "$(sha256sum <"$tmp/body" | cut -c1-12)" "$(wc -c <"$tmp/body")" \
      "$(sha256sum <"$main_out/$rel" | cut -c1-12)" "$(wc -c <"$main_out/$rel")"
    bad=$((bad + 1))
  fi
done < <(cd "$main_out" && find . -type f | sed 's|^\./||' | sort)

if [ "$bad" -ne 0 ]; then
  echo "site-published: $bad of $total file(s) at $HOST differ from $main_out" >&2
  echo "site-published: the published tree is not ${BASE} — redeploy it: ${DEPLOY}" >&2
  exit 1
fi

echo "site-published: $ok/$total file(s) at $HOST match $main_out"
exit 0
