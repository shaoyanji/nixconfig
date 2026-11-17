#!/usr/bin/env bash
# The page suites in one command, for a machine with node and a browser.
#
# `loom-cli bench` measures the same segment from inside the process, which is
# how the gate stays quiet. These suites are the other half: the page's own
# redraw, its constraint sidebar, the identity a retune keeps, and the same 5 ms
# target measured from a browser over the DevTools protocol. They run here so the
# scheduled job and a person at a terminal execute exactly the same thing.
#
# Each suite gets a fresh server. `smoke` plants a span and `retune` plants
# another, and a suite that starts on someone else's leftovers is testing the
# leftovers rather than itself.
#
# The latency suite gates the 5 ms the README publishes. Below MIN_CORES it is
# reported as advisory instead of failing, for the same reason the sweep is: a
# two-core box cannot hold a 2 ms window, so that run measured the machine.
set -uo pipefail

PORT=${PORT:-8787}
CDP_PORT=${CDP_PORT:-9222}
MIN_CORES=${MIN_CORES:-4}
BASE="http://127.0.0.1:$PORT/"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
# smoke.mjs reads the port from the environment rather than an argument.
export LOOM_PORT=$PORT

cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 0)
case "$cores" in
  '' | *[!0-9]*) cores=0 ;;
esac

[ -x ./target/release/loom-srv ] || {
  echo "build first: cargo build --release --locked" >&2
  exit 3
}
export NODE_PATH=$ROOT/node_modules
node -e 'require("ws")' 2>/dev/null || {
  echo "the CDP suites need ws: npm install --no-save ws (then NODE_PATH=$PWD/node_modules)" >&2
  exit 3
}

browser=""
for b in chromium chromium-browser google-chrome google-chrome-stable; do
  if command -v "$b" >/dev/null 2>&1; then
    browser=$b
    break
  fi
done
[ -n "$browser" ] || {
  echo "no chromium or chrome on PATH: the two CDP suites cannot run" >&2
  exit 3
}

srv_pid=""
chrome_pid=""
cleanup() {
  [ -n "$srv_pid" ] && kill "$srv_pid" 2>/dev/null
  [ -n "$chrome_pid" ] && kill "$chrome_pid" 2>/dev/null
  pkill -f "remote-debugging-port=$CDP_PORT" 2>/dev/null
  return 0
}
trap cleanup EXIT

start_srv() {
  if [ -n "$srv_pid" ]; then
    kill "$srv_pid" 2>/dev/null
    sleep 0.3
  fi
  LOOM_PORT=$PORT LOOM_DATA=off ./target/release/loom-srv >/tmp/loom-page-srv.log 2>&1 &
  srv_pid=$!
  for _ in $(seq 60); do
    curl -sf -o /dev/null "$BASE" && return 0
    sleep 0.1
  done
  echo "the server did not answer on $BASE" >&2
  tail -5 /tmp/loom-page-srv.log >&2
  return 1
}

start_chrome() {
  if [ -n "$chrome_pid" ]; then
    kill "$chrome_pid" 2>/dev/null
    sleep 0.3
  fi
  rm -rf /tmp/loom-page-cdp
  "$browser" --headless=new --no-sandbox --disable-gpu --disable-dev-shm-usage \
    --remote-debugging-port="$CDP_PORT" --user-data-dir=/tmp/loom-page-cdp \
    about:blank >/tmp/loom-page-chrome.log 2>&1 &
  chrome_pid=$!
  for _ in $(seq 60); do
    curl -sf -o /dev/null "http://127.0.0.1:$CDP_PORT/json/list" && return 0
    sleep 0.25
  done
  echo "the browser did not open CDP on $CDP_PORT" >&2
  tail -5 /tmp/loom-page-chrome.log >&2
  return 1
}

failed=0
advisory=0
run() {
  name=$1
  shift
  if "$@"; then
    printf '%-8s pass\n' "$name"
  else
    printf '%-8s FAIL\n' "$name"
    failed=$((failed + 1))
  fi
}

printf 'machine: %s cores · %s · %s\n\n' "$cores" "$browser" "$(uname -sr 2>/dev/null || echo unknown)"

start_srv || exit 3
run smoke node web/smoke.mjs "$BASE"
if [ "$cores" -lt "$MIN_CORES" ]; then
  advisory=1
  if node web/window.mjs "$BASE"; then
    printf '%-8s pass\n' window
  else
    printf '%-8s advisory: below the %s cores the target came from\n' window "$MIN_CORES"
  fi
else
  run window node web/window.mjs "$BASE"
fi

start_srv || exit 3
start_chrome || exit 3
run retune node web/retune.mjs "$BASE"
# retune leaves a planted span behind; uitest counts constraints from none.
start_srv || exit 3
run uitest node web/uitest.mjs "$BASE"

echo
if [ "$failed" -ne 0 ]; then
  echo "$failed page suite(s) failed"
  exit 1
fi
if [ "$advisory" -eq 1 ]; then
  echo "all page suites pass, latency advisory on $cores cores"
else
  echo "all page suites pass on $cores cores"
fi
