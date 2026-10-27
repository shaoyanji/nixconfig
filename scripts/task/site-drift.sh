#!/usr/bin/env bash
# A deploy can finish and still leave the previous tree serving: nginx keeps the
# store path it read at activation, so a boot-only switch, a rollback and a flake
# ref that never moved all look identical from outside. The site vhosts therefore
# say which store path they are serving (`X-Site-Path`), and this compares that
# answer with the tree's own host instantiation (`.#delphi-site`, which IS
# `system.build.delphiSite` — not a second, card-less build).
#
# One HTTP request with a timeout and one eval: no ssh (a pre-switch hook that
# opens ssh hung for five minutes on an interactive browser check), no journal,
# no log parsing.
#
# EXIT
#   0  the live server serves the path this tree builds
#   1  it serves a different path — the deploy is stale or the tree moved after it
#   2  cannot tell: no answer, no header, or the eval failed
#
# Those are this script's codes, which is what CI and a direct caller see. Under
# `task` go-task reports every failure as 201, so read the message: it says which
# of the two it was.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2

ATTR=${ATTR:-delphi-site}
HOST_HEADER=${HOST_HEADER:-delphi}
URL=${URL:-http://127.0.0.1/}
TIMEOUT=${TIMEOUT:-5}
EVAL_TIMEOUT=${EVAL_TIMEOUT:-180}

headers="$(mktemp)"
pathfile="$(mktemp)"
trap 'rm -f "$headers" "$pathfile"' EXIT

if ! curl -fsS --max-time "$TIMEOUT" -o /dev/null -D "$headers" \
  -H "Host: ${HOST_HEADER}" "$URL"; then
  echo "site-drift: ${URL} (Host: ${HOST_HEADER}) gave no usable answer within ${TIMEOUT}s" >&2
  echo "site-drift: run this where the page is served, or point URL= at it (URL=http://10.99.0.53/)" >&2
  exit 2
fi

served="$(awk -F': *' 'tolower($1)=="x-site-path" {gsub(/\r$/,"",$2); print $2; exit}' "$headers")"
if [ -z "$served" ]; then
  echo "site-drift: the response carried no X-Site-Path header" >&2
  echo "site-drift: the serving generation predates the header (rebuild it), or HOST_HEADER=${HOST_HEADER} names the wrong vhost" >&2
  exit 2
fi

# The guard prints its own summary line on stdout, so nix's output is captured
# inside the guarded command rather than from the pipeline.
bash scripts/task/oom-guard.sh --timeout "$EVAL_TIMEOUT" --label "eval .#${ATTR}" -- \
  bash -c 'nix eval --raw ".#$1.outPath" > "$2"' _ "$ATTR" "$pathfile"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "site-drift: could not evaluate .#${ATTR}.outPath (guard rc=${rc})" >&2
  exit 2
fi

expected="$(tr -d '\n' <"$pathfile")"
if [ -z "$expected" ]; then
  echo "site-drift: .#${ATTR}.outPath evaluated to an empty string" >&2
  exit 2
fi

if [ "$served" = "$expected" ]; then
  echo "site-drift: OK — serving ${served}"
  exit 0
fi

echo "site-drift: STALE — the live server is not serving what this tree builds" >&2
echo "  served: ${served}" >&2
echo "  tree:   ${expected}" >&2
echo "  fix:    task infra:deploy:host:delphi   (or task infra:rebuild:nixos locally)" >&2
exit 1
