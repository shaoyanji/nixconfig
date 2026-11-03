#!/usr/bin/env bash
# selector-sidecar-check.sh — the gate under the resident stage 1.
#
# What it proves, and why a separate gate from `checks:selector`: that one scores
# the selector's answers (p, coverage, S) on the portable path — the interpreter,
# which every host has. This one proves the accelerator is the same answer: the
# daemon and the interpreter must be byte-identical on stdout, stderr AND exit
# code, over a sample that includes each registry, a refusable question and an
# abstain. A daemon that is merely faster is not worth a unit; one that is faster
# and different is worse than none, and the difference would be invisible in a
# query alone.
#
#   1. lifecycle — `start` must not report success before readiness, a second
#                  `start` must be a no-op, and `stop` must actually remove the
#                  socket and leave `status` failing.
#   2. parity    — same bytes, same exit code, sidecar vs Q_NO_SIDECAR=1.
#   3. speed     — reported, not asserted: a threshold on a shared host is a
#                  flake generator, and the numbers are what the reader wants.
#
# It boots on a PRIVATE socket: `stop` removes the socket it was given, and the
# default one belongs to the login unit — the kg gate left the fast path dead
# until the next login exactly that way.
#
# Cost: ~6 questions x 2 paths, so ~3 s. Exit 0 = clean, 1 = drift.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
SIDE="$REPO/scripts/task/selector-sidecar.sh"
Q="$REPO/scripts/task/q.sh"
export SELECTOR_SOCKET="${XDG_RUNTIME_DIR:-/tmp}/selector-check-$$.sock"
trap 'rm -f "$SELECTOR_SOCKET"' EXIT

fail=0
ok() { printf 'ok    %s\n' "$1"; }
bad() {
  printf 'FAIL  %s\n' "$1"
  fail=1
}
say() { printf '\n== %s ==\n' "$1"; }

"$SIDE" stop >/dev/null 2>&1 || true

say "lifecycle"
if out="$("$SIDE" start 2>&1)"; then
  ok "start exits 0"
else
  bad "start failed: $out"
  exit 1
fi
[ -S "$SELECTOR_SOCKET" ] && ok "socket exists at $SELECTOR_SOCKET" || bad "no socket at $SELECTOR_SOCKET"
if stats="$("$SIDE" status 2>/dev/null)" && jq -e '.pid > 0 and .model_bytes > 0' >/dev/null 2>&1 <<<"$stats"; then
  ok "status reports the loaded model ($(jq -r '.model_bytes' <<<"$stats") B, $(jq -r '.load_ms' <<<"$stats") ms to load)"
else
  bad "status did not report a loaded model: ${stats:-no output}"
fi
if "$SIDE" start >/dev/null 2>&1; then
  ok "a second start is a no-op"
else
  bad "a second start failed"
fi

# `ask` is the client the reader uses by hand; the request body is built by jq, so
# a question carrying a quote must survive the wire unchanged.
if out="$("$SIDE" ask 'which notes reference the “selector” predesign?' 2>&1)"; then
  if jq -e 'has("registry") or .refused == true' >/dev/null 2>&1 <<<"$out"; then
    ok "ask survives a quoted question"
  else
    bad "ask returned neither an object nor a refusal: $out"
  fi
else
  bad "ask failed: ${out:-no output}"
fi

say "parity (sidecar vs Q_NO_SIDECAR=1)"
# One question per registry, a numeric graph question, a stage-1 abstain and an
# empty answer: the four paths where stage 1 had to be right for the row set to
# match gold, plus the one it declines.
questions=(
  "which notes are blocked"
  "which active hosts are in the laptop category"
  "which tasks are retired"
  "which hosts are graph hubs with at least twenty inbound edges"
  "what is frieren's CPU temperature"
  "which notes mention kubernetes"
)
for q in "${questions[@]}"; do
  rc_side=0
  rc_fall=0
  side="$(bash "$Q" --question "$q" 2>&1)" || rc_side=$?
  fall="$(Q_NO_SIDECAR=1 bash "$Q" --question "$q" 2>&1)" || rc_fall=$?
  if [ "$side" = "$fall" ] && [ "$rc_side" = "$rc_fall" ]; then
    ok "same answer, exit $rc_side: $q"
  else
    bad "drift on '$q' (exit $rc_side vs $rc_fall)"
    diff <(printf '%s\n' "$side") <(printf '%s\n' "$fall") | sed 's/^/      /' >&2 || true
  fi
done

say "speed (reported, not asserted)"
median() {
  python3 -c 'import statistics,sys; print(round(statistics.median(float(x) for x in sys.argv[1:]),1))' "$@"
}
for q in "which notes are blocked" "what is frieren's CPU temperature"; do
  side_ms=()
  fall_ms=()
  for _ in 1 2 3; do
    s=$(date +%s%N)
    bash "$Q" --question "$q" >/dev/null 2>&1 || true
    e=$(date +%s%N)
    side_ms+=("$(((e - s) / 1000000))")
    s=$(date +%s%N)
    Q_NO_SIDECAR=1 bash "$Q" --question "$q" >/dev/null 2>&1 || true
    e=$(date +%s%N)
    fall_ms+=("$(((e - s) / 1000000))")
  done
  printf '      %-52s resident %4s ms   interpreter %4s ms\n' "$q" "$(median "${side_ms[@]}")" "$(median "${fall_ms[@]}")"
done

say "teardown"
"$SIDE" stop >/dev/null 2>&1 || true
[ -S "$SELECTOR_SOCKET" ] && bad "stop left the socket behind" || ok "stop removed the socket"
if "$SIDE" status >/dev/null 2>&1; then
  bad "status still succeeds after stop"
else
  ok "status fails after stop"
fi

echo
if [ "$fail" = 0 ]; then
  echo "verdict          : the resident stage 1 answers exactly what the interpreter answers"
  exit 0
fi
echo "verdict          : drift — see FAIL above"
exit 1
