#!/usr/bin/env bash
# pane-nudge — a one-line reference into an agent pane, not a task brief.
#
# The watcher's old nudge pasted the whole task (plus the jev JSON) into each
# pane — the model re-read that prose every tick. The pane already knows how
# to read the xs ledger, so the line it gets is just the coordinates:
#
#   xs SUBJECT=nixconfig:<id> CLAIM=<path> ACTION=<gate> — detail on the ledger
#
# Usage: pane-nudge.sh TARGET=agents:2 SUBJECT=nixconfig:<id> \
#          CLAIM=<path> ACTION=<one-line>
# Exit: 0 sent · 1 tmux/target problem · 2 bad input.
#
# Mechanics follow tmux-pane-driving: C-u clears a half-typed input, then a
# named buffer + paste-buffer + one Enter — never send-keys for the text itself.
# No Escape: it aborts a worker's running turn in a TUI, and in a readline pane
# it leaves a pending meta prefix that swallows the paste's first character.
# The buffer is named, not the default one, so a nudge does not overwrite the
# operator's own paste buffer.
set -euo pipefail

die() { printf 'pane-nudge: %s\n' "$*" >&2; exit "${2:-2}"; }
command -v tmux >/dev/null || die "tmux is not on PATH" 1

target=${TARGET:-}
subject=${SUBJECT:-}
claim=${CLAIM:-}
action=${ACTION:-}

[ -n "$target" ] || die "TARGET=<session>:<window> is required"
[ -n "$subject" ] || die "SUBJECT=<repo>:<id> is required"
[ -n "$action" ] || die "ACTION=<one line> is required"

tmux list-windows -a -F '#{session_name}:#{window_index}' 2>/dev/null |
  grep -qx "$target" || die "no window $target (agents-tmux.sh list to see them)" 1

line="xs $subject CLAIM=${claim:-none} ACTION=$action — detail on the ledger"

# load-buffer's -t is a target *client*, not a pane; the pane belongs on
# paste-buffer. A leftover buffer would shadow the next nudge, so delete it.
buf="pane-nudge-$$"
trap 'tmux delete-buffer -b "$buf" 2>/dev/null || true' EXIT

# Clear any half-typed input so the nudge doesn't paste over it, then the
# three-step send: load, paste, Enter.
tmux send-keys -t "$target" C-u
sleep 0.2
printf '%s\n' "$line" | tmux load-buffer -b "$buf" -
tmux paste-buffer -b "$buf" -t "$target"
tmux send-keys -t "$target" Enter

printf 'pane-nudge: sent to %s — %s\n' "$target" "$line"
