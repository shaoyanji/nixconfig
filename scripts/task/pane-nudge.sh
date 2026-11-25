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
# Mechanics follow tmux-pane-driving: Escape + C-u clears a half-typed input
# (load-buffer pastes ON TOP of existing text), then load-buffer +
# paste-buffer + one Enter — never send-keys for the text itself.
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
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$line" >"$tmp"

# Clear any half-typed input so the nudge doesn't paste over it, then the
# three-step send: load, paste, Enter.
tmux send-keys -t "$target" Escape
sleep 0.2
tmux send-keys -t "$target" C-u
tmux load-buffer -t "$target" "$tmp"
tmux paste-buffer -t "$target"
tmux send-keys -t "$target" Enter

printf 'pane-nudge: sent to %s — %s\n' "$target" "$line"
