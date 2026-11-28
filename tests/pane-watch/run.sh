#!/usr/bin/env bash
# Regression fixture for scripts/task/pane-watch.sh — the pane state report the
# pane-idle-watch cron reads to decide what to drive.
#
# What it pins, because each is a mistake on record or one keystroke away:
#   * a state comes from the capture's working/thinking line or composer text,
#     never from a timer's magnitude and never from the footer — the footer
#     (`SWE-2 High · bypass · 1 shell ↓  ctrl+o to expand edits`) and Devin's
#     static Braille header sit on every screen, busy or idle;
#   * an `ssh` pane is included and classified, never blanket-skipped: a
#     capture showing an agent TUI is IDLE/BUSY (a pane attached to delphi's
#     freebuff over the tunnel stays driveable), a raw remote shell is SKIP and
#     never typed into, and SKIP is an ssh-only verdict — a local shell pane
#     with no TUI marker is UNKNOWN;
#   * `TMUX_TMPDIR` is exported by the script itself: a cron job inherits none,
#     and without it every pane reads UNKNOWN while the server is alive;
#   * a missing server is one `UNKNOWN: no tmux server` line at exit 0 — not a
#     crash, and not one UNKNOWN per window that never existed.
#
# tmux is stubbed on PATH, so the fixture proves classification without a live
# session and cannot disturb a pane.
#
# Coverage is asserted both ways: a case listed below that stops running, or one
# that runs without being listed, fails the fixture.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
script="$repo/scripts/task/pane-watch.sh"
[ -f "$script" ] || { echo "fixture: $script missing" >&2; exit 2; }

expected="an idle composer reads IDLE
a working timer reads BUSY
a thinking spinner reads BUSY
a capture with no marker reads UNKNOWN
no window list is one UNKNOWN line at exit 0
a blank target row is skipped
an ssh pane showing an agent TUI reads IDLE
an ssh pane showing a working timer reads BUSY
an ssh pane at a raw remote shell reads SKIP
a local shell pane is UNKNOWN, not SKIP
the persistent footer chrome is not BUSY
the Braille header logo is not BUSY
several panes report in window order
TMUX_TMPDIR defaults to the server socket dir
an exported TMUX_TMPDIR is preserved"

fail=0
cases=0
ran=()
ok() { echo "ok   $*"; }
bad() {
  echo "FAIL $*"
  fail=1
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
log="$work/tmux-calls"
out=""
rc=0

# The stub records every call with the TMUX_TMPDIR it saw, so both the
# classification and the exported socket dir are observable. It answers
# list-windows with the scenario's target rows and capture-pane with the
# scenario's capture file for that pane.
cat >"$work/bin/tmux" <<'STUB'
#!/usr/bin/env bash
printf 'TMUX_TMPDIR=%s %s\n' "${TMUX_TMPDIR:-unset}" "$*" >>"${TMUX_STUB_LOG:?}"
case "${1:-}" in
  list-windows) printf '%s\n' "${TMUX_STUB_TARGETS:-}" ;;
  capture-pane)
    target=""
    while [ $# -gt 0 ]; do
      case "$1" in -t) target="$2"; shift 2 ;; *) shift ;; esac
    done
    [ -f "${TMUX_STUB_CAPTURES:?}/$target" ] && cat "$TMUX_STUB_CAPTURES/$target"
    ;;
esac
exit 0
STUB
chmod +x "$work/bin/tmux"

scenario() { # name
  mkdir -p "$work/$1/captures"
  : >"$work/$1/targets"
}
target() { printf '%s\n' "$2" >>"$work/$1/targets"; }
pane() { printf '%s\n' "$3" >"$work/$1/captures/$2"; }

watch() { # scenario [env...]
  local name="$1"
  shift
  : >"$log"
  out="$(
    env "$@" PATH="$work/bin:$PATH" TMUX_STUB_LOG="$log" \
      TMUX_STUB_CAPTURES="$work/$name/captures" \
      TMUX_STUB_TARGETS="$(cat "$work/$name/targets")" \
      bash "$script" 2>"$work/$name/err"
  )"
  rc=$?
}

check() { # label scenario expected-output
  cases=$((cases + 1))
  ran+=("$1")
  if [ "$rc" != 0 ]; then
    bad "$1: exit $rc, want 0 — $(cat "$work/$2/err")"
    return
  fi
  if [ "$out" != "$3" ]; then
    bad "$1: got '$(tr '\n' '|' <<<"$out")' want '$(tr '\n' '|' <<<"$3")'"
    return
  fi
  ok "$1"
}

check_log() { # label needle
  cases=$((cases + 1))
  ran+=("$1")
  if grep -q -- "$2" "$log"; then ok "$1"; else bad "$1: $(cat "$log")"; fi
}

# --- the three states ---------------------------------------------------------
scenario idle
target idle 'agents:2.0|bash'
pane idle 'agents:2.0' '  Add to the current task'
watch idle
check "an idle composer reads IDLE" idle 'IDLE: agents:2.0'

scenario working
target working 'agents:2.0|bash'
pane working 'agents:2.0' '⠋ working... 12s  ■ Esc'
watch working
check "a working timer reads BUSY" working 'BUSY: agents:2.0'

scenario thinking
target thinking 'agents:2.0|bash'
pane thinking 'agents:2.0' '⠋ Thinking · 8s (esc twice to interrupt)'
watch thinking
check "a thinking spinner reads BUSY" thinking 'BUSY: agents:2.0'

scenario unknown
target unknown 'agents:2.0|bash'
pane unknown 'agents:2.0' 'some log line and then nothing at all'
watch unknown
check "a capture with no marker reads UNKNOWN" unknown 'UNKNOWN: agents:2.0'

# --- no server: one line, exit 0 ---------------------------------------------
scenario noserver
watch noserver
check "no window list is one UNKNOWN line at exit 0" noserver 'UNKNOWN: no tmux server or no agent panes'

# --- a blank row is not a pane ------------------------------------------------
scenario blank
target blank ''
target blank 'agents:2.0|bash'
pane blank 'agents:2.0' 'Enter a coding task or / for commands'
watch blank
check "a blank target row is skipped" blank 'IDLE: agents:2.0'

# --- ssh panes: the tunnel is driveable, a raw shell is not --------------------
scenario ssh-idle
target ssh-idle 'agents:3.0|ssh'
pane ssh-idle 'agents:3.0' '  Enter a coding task or / for commands'
watch ssh-idle
check "an ssh pane showing an agent TUI reads IDLE" ssh-idle 'IDLE: agents:3.0'

scenario ssh-busy
target ssh-busy 'agents:3.0|ssh'
pane ssh-busy 'agents:3.0' '❭ deploy the gate
⠋ Running tools · 31s'
watch ssh-busy
check "an ssh pane showing a working timer reads BUSY" ssh-busy 'BUSY: agents:3.0'

scenario ssh-shell
target ssh-shell 'agents:3.0|ssh'
pane ssh-shell 'agents:3.0' 'devji@delphi:~$ tmux ls
agents: 3 windows (created Mon Nov 24 09:11:04 2026)'
watch ssh-shell
check "an ssh pane at a raw remote shell reads SKIP" ssh-shell 'SKIP: agents:3.0 (remote shell, not driven)'

scenario local-shell
target local-shell 'agents:1.0|bash'
pane local-shell 'agents:1.0' 'devji@frieren:~/Documents/nixconfig$ git status -sb
## main...origin/main'
watch local-shell
check "a local shell pane is UNKNOWN, not SKIP" local-shell 'UNKNOWN: agents:1.0'

# --- chrome is not a state ----------------------------------------------------
scenario footer
target footer 'agents:1.0|bash'
pane footer 'agents:1.0' '  Add to the current task
SWE-2 High · bypass · 1 shell ↓  ctrl+o to expand edits'
watch footer
check "the persistent footer chrome is not BUSY" footer 'IDLE: agents:1.0'

scenario logo
target logo 'agents:1.0|bash'
pane logo 'agents:1.0' '⣿⣿⣿⣿ ⠿⢿
  Add to the current task'
watch logo
check "the Braille header logo is not BUSY" logo 'IDLE: agents:1.0'

# --- several panes, window order ---------------------------------------------
scenario multi
target multi 'agents:1.0|bash'
target multi 'agents:2.0|bash'
pane multi 'agents:1.0' '  Add to the current task'
pane multi 'agents:2.0' '⠋ working... 3s  ■ Esc'
watch multi
check "several panes report in window order" multi 'IDLE: agents:1.0
BUSY: agents:2.0'

# --- TMUX_TMPDIR is exported by the script, not inherited ---------------------
scenario tmpdir
target tmpdir 'agents:2.0|bash'
pane tmpdir 'agents:2.0' '  Add to the current task'
watch tmpdir -u TMUX_TMPDIR
check "TMUX_TMPDIR defaults to the server socket dir" tmpdir 'IDLE: agents:2.0'
check_log "TMUX_TMPDIR defaults to the server socket dir" 'TMUX_TMPDIR=/run/user/1000 '

watch tmpdir TMUX_TMPDIR=/run/user/4242
check "an exported TMUX_TMPDIR is preserved" tmpdir 'IDLE: agents:2.0'
check_log "an exported TMUX_TMPDIR is preserved" 'TMUX_TMPDIR=/run/user/4242 '

# --- coverage, both ways ------------------------------------------------------
while IFS= read -r name; do
  grep -qxF -- "$name" <<<"$expected" || bad "unlisted case: ${name}"
done < <(printf '%s\n' "${ran[@]}" | sort -u)
while IFS= read -r name; do
  [ -n "$name" ] || continue
  printf '%s\n' "${ran[@]}" | grep -qxF -- "$name" || bad "case never ran: $name"
done <<<"$expected"

echo "pane-watch fixture: ${cases} cases"
[ "$fail" = 0 ] || exit 1
