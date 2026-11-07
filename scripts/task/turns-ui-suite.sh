#!/usr/bin/env bash
# turns-ui-suite.sh — the dashboard's browser suite, on whatever host runs it.
#
# The reader is one page with no framework: the parts worth proving are the
# parts a person uses — movement, the finder, the key list, the URL, and a new
# turn announcing itself. This script asserts all of them against a real
# Chromium through `agent-browser`, and prints one PASS/FAIL line per check.
#
# It is deliberately host-agnostic: the same file runs on delphi against a
# loopback port, and inside `templates/agent-shell` on clanker against the
# public mount — which is the demo that matters, because that box has no
# tailnet, no token and no way to prompt.
#
# Env:
#   TARGET=          URL (default https://delphi.bountystash.com/turns/)
#   PROMPTS=         absent (default, the public reader) | present (tailnet mount)
#   WATCH=0          skip the toast phase (it needs a POST from a host with a token)
#   WATCH_SECONDS=   how long that phase waits (default 180)
#   EXPECT_SUBJECT=  subject the orchestrator posts (default nixconfig:turns-ui)
#
# The toast phase prints `PHASE toast-watch` and then polls: an orchestrator on
# another host watches a job log for that line and posts the turn. That is why
# the line exists at all — it is the handshake, not decoration.
#
# Exit: 0 every check passed · 1 at least one failed · 2 preflight
set -uo pipefail

TARGET=${TARGET:-https://delphi.bountystash.com/turns/}
PROMPTS=${PROMPTS:-absent}
WATCH=${WATCH:-1}
WATCH_SECONDS=${WATCH_SECONDS:-180}
EXPECT_SUBJECT=${EXPECT_SUBJECT:-nixconfig:turns-ui}

fail=0
checks=0

ab() { timeout 120 agent-browser "$@" 2>/dev/null; }
ev() { ab eval "$1" | tr -d '\n' | jq -r . 2>/dev/null; }

ok() {
  checks=$((checks + 1))
  if [ "$2" = "$3" ]; then
    printf 'PASS  %-28s %s\n' "$1" "$3"
  else
    printf 'FAIL  %-28s got=%s want=%s\n' "$1" "${2:-<empty>}" "$3"
    fail=1
  fi
}
# For "it changed" and "it is not zero": an empty value is a failure, not a pass.
okne() {
  checks=$((checks + 1))
  if [ -n "$2" ] && [ "$2" != "$3" ]; then
    printf 'PASS  %-28s %s\n' "$1" "$2"
  else
    printf 'FAIL  %-28s got=%s want!=%s\n' "$1" "${2:-<empty>}" "$3"
    fail=1
  fi
}
section() { printf '\n--- %s\n' "$1"; }
die() {
  printf 'suite: %s\n' "$*" >&2
  exit 2
}

command -v agent-browser >/dev/null || die "agent-browser is not on PATH (use the agent-shell devShell)"
command -v jq >/dev/null || die "jq is not on PATH"
curl -sfI --max-time 20 "$TARGET" >/dev/null || die "$TARGET does not answer"

wait_live() {
  local i state
  for i in $(seq 1 30); do
    state=$(ev 'document.body.dataset.stream')
    [ "$state" = live ] && break
    sleep 1
  done
  printf '%s' "$state"
}

# `live` is the stream, not the rows: the history frame is one big inner patch
# and over a WAN it lands a beat later. Counting cards the instant the socket
# opens reads 0 from a box outside the fleet (measured on clanker, 2026-11-07).
wait_cards() {
  local i n=0
  for i in $(seq 1 40); do
    n=$(ev "document.querySelectorAll('article.turn').length")
    [ "${n:-0}" -gt 30 ] && break
    sleep 0.5
  done
  printf '%s' "$n"
}

section "posture at $TARGET"
ab open "$TARGET" >/dev/null
state=$(wait_live)
ok stream "$state" live
ok cards-present "$([ "$(wait_cards)" -gt 30 ] && echo true || echo false)" true
# Everything below is meaningless on an empty page, and an empty page makes
# several comparisons pass by accident ("0 turns" equals "0 turns").
[ "$state" = live ] || die "the page at $TARGET never reported a live stream"
forms=$(ev "document.querySelectorAll('article.turn .ask').length")
if [ "$PROMPTS" = absent ]; then
  ok no-prompt-form "$forms" 0
else
  okne prompt-form-present "$forms" 0
fi
total=$(ev "document.querySelectorAll('article.turn').length")
[ "${total:-0}" -gt 30 ] || die "$TARGET served ${total:-0} turns; the suite needs a full log to move through"

section "movement"
ab press j >/dev/null
sleep 1
ok j-marks-card "$(ev "Boolean(document.querySelector('[data-current]'))")" true
first=$(ev "document.querySelector('[data-current]').id")
okne j-scrolled "$(ev 'Math.round(document.getElementById("log").scrollTop)')" 0
ab press j >/dev/null
sleep 1
second=$(ev "document.querySelector('[data-current]').id")
okne j-advances "$second" "$first"
ab press k >/dev/null
sleep 1
ok k-returns "$(ev "document.querySelector('[data-current]').id")" "$first"
ab press g >/dev/null
sleep 1
ok g-tops "$(ev 'Math.round(document.getElementById("log").scrollTop)')" 0
ab press G >/dev/null
sleep 1
okne G-bottoms "$(ev 'Math.round(document.getElementById("log").scrollTop)')" 0
ab press g >/dev/null
sleep 1
firstid=$(ev "document.querySelectorAll('article.turn')[0].id")
ab press Shift+ArrowDown >/dev/null
sleep 1
okne shift-down-moves "$(ev "document.querySelector('[data-current]').id")" "$firstid"
ab press g >/dev/null
sleep 1
ab press G >/dev/null
sleep 1
ok totop-href "$(ev 'document.getElementById("totop").getAttribute("href")')" "#top"
ab click '#totop' >/dev/null
sleep 1
ok totop-scrolls "$(ev 'Math.round(document.getElementById("log").scrollTop)')" 0

section "key list"
ok help-starts-closed "$(ev 'document.getElementById("help").hidden')" true
ab press '?' >/dev/null
sleep 1
ok help-opens "$(ev 'document.getElementById("help").hidden')" false
ok help-rows "$(ev "document.querySelectorAll('#help .help-keys dt').length")" 10
ok help-is-modal "$(ev 'document.body.classList.contains("helping")')" true
ab press j >/dev/null
sleep 1
ok help-blocks-j "$(ev 'Math.round(document.getElementById("log").scrollTop)')" 0
ab press Escape >/dev/null
sleep 1
ok esc-closes-help "$(ev 'document.getElementById("help").hidden')" true
ab click '#help-open' >/dev/null
sleep 1
ok button-opens-help "$(ev 'document.getElementById("help").hidden')" false
ab click '#help-close' >/dev/null
sleep 1
ok button-closes-help "$(ev 'document.getElementById("help").hidden')" true

section "finder"
ab press / >/dev/null
sleep 1
ok finder-focused "$(ev 'document.activeElement.id')" find
ab keyboard type "umami" >/dev/null
sleep 1
# Read the two counts and the label in ONE eval, and compare them to each other.
# A live log grows during the run: `2/41` measured before a turn arrived and
# `2/43` a few seconds later is not a finder bug (measured on clanker, 2026-11-07).
ok finder-narrows "$(ev "(() => { const a = document.querySelectorAll('article.turn').length; const v = document.querySelectorAll('article.turn:not([hidden])').length; return v > 0 && v < a; })()")" true
ok finder-count "$(ev "(() => { const a = document.querySelectorAll('article.turn').length; const v = document.querySelectorAll('article.turn:not([hidden])').length; return document.getElementById('count').textContent === v + '/' + a; })()")" true
ok url-carries-query "$(ev 'location.search')" "?q=umami"
ab keyboard type "zzqqxx" >/dev/null
sleep 1
ok nomatch-shown "$(ev 'document.getElementById("nomatch").hidden === false')" true
ok nomatch-zero "$(ev "document.querySelectorAll('article.turn:not([hidden])').length")" 0
ab press Escape >/dev/null
sleep 1
ok esc-clears "$(ev "document.querySelectorAll('article.turn[hidden]').length")" 0
ok esc-clears-url "$(ev 'location.search')" ""

section "shareable view"
ab open "${TARGET%/}/?q=umami" >/dev/null
state=$(wait_live)
ok shared-stream "$state" live
wait_cards >/dev/null
ok shared-value "$(ev 'document.getElementById("find").value')" "umami"
shared=0
for i in $(seq 1 20); do
  shared=$(ev "document.querySelectorAll('article.turn:not([hidden])').length")
  [ "${shared:-0}" -gt 0 ] && break
  sleep 0.5
done
ok shared-filtered "$(ev "(() => { const a = document.querySelectorAll('article.turn').length; const v = document.querySelectorAll('article.turn:not([hidden])').length; return v > 0 && v < a; })()")" true
ok shared-label "$(ev "(() => { const a = document.querySelectorAll('article.turn').length; const v = document.querySelectorAll('article.turn:not([hidden])').length; return document.getElementById('count').textContent === v + '/' + a; })()")" true

if [ "$WATCH" = 1 ]; then
  section "toast on a new turn"
  ab press Escape >/dev/null
  sleep 1
  ab press G >/dev/null
  sleep 1
  printf 'PHASE toast-watch %s\n' "$EXPECT_SUBJECT"
  toast=0
  for i in $(seq 1 "$((WATCH_SECONDS * 2))"); do
    toast=$(ev "document.querySelectorAll('#toasts .toast').length")
    [ "${toast:-0}" -ge 1 ] && break
    sleep 0.5
  done
  ok toast-arrived "${toast:-0}" 1
  ok toast-subject "$(ev "document.querySelector('#toasts .toast .t-sub')?.textContent ?? ''")" "$EXPECT_SUBJECT"
  okne toast-source "$(ev "document.querySelector('#toasts .toast .t-src')?.textContent ?? ''")" ""
  ab click '#toasts .toast' >/dev/null
  sleep 1
  ok toast-jumps "$(ev "document.querySelector('[data-current] .subject')?.textContent ?? ''")" "$EXPECT_SUBJECT"
  ok toast-dismissed "$(ev "document.querySelectorAll('#toasts .toast').length")" 0
fi

section "console"
console_out=$(ab console || true)
if printf '%s\n' "$console_out" | grep -qiE 'uncaught|exception'; then
  checks=$((checks + 1))
  printf 'FAIL  %-28s %s\n' console-clean "errors in the browser console"
  printf '%s\n' "$console_out" | grep -iE 'uncaught|exception' | head -5
  fail=1
else
  ok console-clean "clean" "clean"
fi

ab close >/dev/null
printf '\n%s\n' "checks=$checks fail=$fail"
exit "$fail"
