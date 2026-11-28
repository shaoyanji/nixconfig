#!/usr/bin/env bash
# pane-watch — report which tmux panes are truly idle, busy, or unknowable.
#
# The pane-idle-watch cron reads this to decide what to drive. Windows are
# discovered, never hardcoded. An `ssh` pane is scanned too, but ONLY when its
# capture shows an agent TUI (freebuff/devin) — a raw remote shell is reported
# SKIP and never typed into. That is what makes an `ssh -t delphi ... tmux
# attach` pane driveable through the tunnel while a plain `ssh host` shell stays
# untouched.
#
# TMUX_TMPDIR must point at the server socket dir: a cron job inherits none, and
# without it `capture-pane` finds nothing and every pane reads UNKNOWN while the
# server is alive.
#
# Ported from the fleet's `~/.hermes/scripts/pane-watch.sh`; `tests/pane-watch`
# is the regression fixture for the states and the ssh rule below.
#
# stdout: one `IDLE|BUSY|UNKNOWN|SKIP: <target>` line per pane.
# Exit: 0 always — a state report, never a failure.
set -uo pipefail

export TMUX_TMPDIR="${TMUX_TMPDIR:-/run/user/1000}"

targets=$(tmux list-windows -a -F '#{session_name}:#{window_index}.#{pane_index}|#{pane_current_command}' 2>/dev/null)

if [ -z "$targets" ]; then
  echo "UNKNOWN: no tmux server or no agent panes"
  exit 0
fi

while IFS='|' read -r p cmd; do
  [ -n "$p" ] || continue
  out=$(tmux capture-pane -t "$p" -p 2>/dev/null | grep -v '^$' | tail -n 12)
  # ssh pane: drive only when the capture shows an agent TUI. A raw remote shell
  # has none of these markers and is never typed into.
  if [ "$cmd" = "ssh" ]; then
    if ! echo "$out" | grep -qiE "Add to the current task|Enter a coding task|for commands|Ask Devin|DeepSeek|❭"; then
      echo "SKIP: $p (remote shell, not driven)"
      continue
    fi
  fi
  # Match active TUI working/thinking indicators only — avoid raw Braille chars
  # like ⠿/⢿ that appear in Devin's static ASCII header logo.
  if echo "$out" | grep -qiE "working\.\.\.|working\.\.|■ Esc|esc twice to interrupt|running command|running \(|Thinking ·|Running tools ·|Typing ·|editing files|running tools"; then
    echo "BUSY: $p"
  elif echo "$out" | grep -qE "Enter a coding task|Add to the current task|for commands|Ask Devin to build|Ask Devin to|^> *$|^❭"; then
    echo "IDLE: $p"
  else
    echo "UNKNOWN: $p"
  fi
done <<<"$targets"
