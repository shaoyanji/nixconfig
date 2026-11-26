#!/usr/bin/env bash
# Regression fixture for scripts/task/pane-nudge.sh — the one-line pane nudge.
#
# What it pins, because each is a mistake on record or one keystroke away:
#   * the tmux-driving contract: C-u clears before the paste, the text travels
#     in a NAMED buffer (never send-keys, never the operator's default buffer),
#     one Enter after, no Escape anywhere — an Escape aborts a worker's running
#     turn, and send-keys for text mangles long lines in a TUI;
#   * the line's shape: `xs <subject> CLAIM=<claim|none> ACTION=<action> —
#     detail on the ledger`, since the pane's only job is reading coordinates;
#   * input validation: missing TARGET/SUBJECT/ACTION exits 2 before any tmux
#     call, a window that does not exist exits 1.
#
# tmux is stubbed on PATH — the fixture proves the call sequence without
# driving a real pane, so it is fast and cannot disturb a live session.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
script="$repo/scripts/task/pane-nudge.sh"
[ -f "$script" ] || { echo "fixture: $script missing" >&2; exit 2; }

fail=0
ok()  { echo "ok   $*"; }
bad() { echo "FAIL $*"; fail=1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
log="$work/tmux-calls"

# The stub records one line per invocation: the subcommand and its args.
# list-windows answers with the window the fixture targets; everything else
# exits 0. load-buffer must swallow stdin like the real one.
cat >"$work/bin/tmux" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"${TMUX_STUB_LOG:?}"
case "${1:-}" in
  list-windows) echo "agents:2" ;;
  load-buffer) cat >/dev/null ;;
esac
exit 0
STUB
chmod +x "$work/bin/tmux"

run() {
  : >"$log"
  env "$@" PATH="$work/bin:$PATH" TMUX_STUB_LOG="$log" bash "$script" >/dev/null 2>"$work/err"
  return $?
}

# --- input validation: die before any tmux call -------------------------------
PATH="$work/bin:$PATH" TMUX_STUB_LOG="$log" bash "$script" >/dev/null 2>&1; rc=$?
[ $rc -eq 2 ] && ok "no TARGET exits 2" || bad "no TARGET: rc=$rc want 2"

: >"$log"
run TARGET=agents:2 SUBJECT=nixconfig:x ACTION=y; rc=$?
if [ $rc -eq 0 ]; then ok "happy path exits 0"; else bad "happy path: rc=$rc — $(cat "$work/err")"; fi

# --- the call sequence ---------------------------------------------------------
# C-u clears before the paste, one Enter after, text in a named buffer, no
# Escape, and the text never travels through send-keys.
if grep -q "send-keys -t agents:2 C-u" "$log"; then ok "C-u clears the input first"; else bad "no C-u clear: $(cat "$log")"; fi
enter_line=$(grep -n "send-keys -t agents:2 Enter" "$log" | head -1 | cut -d: -f1)
cu_line=$(grep -n "send-keys -t agents:2 C-u" "$log" | head -1 | cut -d: -f1)
paste_line=$(grep -n "paste-buffer" "$log" | head -1 | cut -d: -f1)
if [ -n "$cu_line" ] && [ -n "$paste_line" ] && [ -n "$enter_line" ] &&
   [ "$cu_line" -lt "$paste_line" ] && [ "$paste_line" -lt "$enter_line" ]; then
  ok "order: C-u then paste then Enter"
else
  bad "call order wrong: cu=$cu_line paste=$paste_line enter=$enter_line"
fi
if grep -q "load-buffer -b pane-nudge-" "$log"; then ok "text travels in a named buffer"; else bad "load-buffer not named: $(grep load-buffer "$log")"; fi
if grep "send-keys" "$log" | grep -qv "C-u\|Enter"; then bad "send-keys carried more than C-u/Enter: $(grep send-keys "$log")"; else ok "send-keys carries only C-u and Enter"; fi
if grep -q "Escape" "$log"; then bad "an Escape was sent — it aborts a worker's turn"; else ok "no Escape anywhere"; fi
if grep -q "delete-buffer -b pane-nudge-" "$log"; then ok "the named buffer is deleted after"; else bad "buffer not deleted: $(cat "$log")"; fi

# --- the line's shape ------------------------------------------------------------
TARGET=agents:2 SUBJECT=nixconfig:demo CLAIM=scripts/x ACTION="gate-change|0.9|0.8: the-thing" \
  PATH="$work/bin:$PATH" TMUX_STUB_LOG="$log" bash "$script" >"$work/out" 2>/dev/null
if grep -qF 'xs nixconfig:demo CLAIM=scripts/x ACTION=gate-change|0.9|0.8: the-thing — detail on the ledger' "$work/out"; then
  ok "the line carries subject, claim, action and the ledger pointer"
else
  bad "line shape wrong: $(cat "$work/out")"
fi

# --- CLAIM empty degrades to none ------------------------------------------------
TARGET=agents:2 SUBJECT=nixconfig:demo ACTION=act PATH="$work/bin:$PATH" TMUX_STUB_LOG="$log" \
  bash "$script" >"$work/out" 2>/dev/null
grep -qF "CLAIM=none" "$work/out" && ok "empty CLAIM degrades to none" || bad "CLAIM=none missing: $(cat "$work/out")"

# --- a window that does not exist exits 1 -----------------------------------------
TARGET=agents:99 SUBJECT=nixconfig:x ACTION=y PATH="$work/bin:$PATH" TMUX_STUB_LOG="$log" \
  bash "$script" >/dev/null 2>"$work/err"; rc=$?
if [ $rc -eq 1 ] && grep -q "no window" "$work/err"; then ok "unknown window exits 1, named"; else bad "unknown window: rc=$rc — $(cat "$work/err")"; fi

[ $fail -eq 0 ] && echo "pane-nudge:test: all cases pass"
exit $fail
