#!/usr/bin/env bash
# agents-tmux.sh — agent lane status by name, not index.
#
# `tmux capture-pane -t 0:3.1` breaks the moment a lane opens or closes; the
# lanes already carry names — in `pane_title` (`~> hermes`) for titled panes,
# in `window_name` otherwise. This resolves either to a window_id once and
# captures that: `list` is the pane map, `show` the tail.
#
# xs remains the verified record (`task agents:xs:list`) — this is the live
# view: a pane that printed nothing proves nothing, a logged turn does.
# Task: agents:tmux, agents:tmux:show.
set -euo pipefail

die() { printf 'agents-tmux: %s\n' "$*" >&2; exit 2; }
command -v tmux >/dev/null || die "tmux is not on PATH"

# name → session:window_id, matching pane_title (with or without the `~>`
# prefix the panes here carry) first, then window_name.
resolve() {
  tmux list-windows -a -F '#{pane_title}|#{window_name}|#{session_name}:#{window_id}' 2>/dev/null |
    awk -F'|' -v n="$1" '
      $1 == "~> " n || $1 == n {print $3; found=1; exit}
      $2 == n && !found {c = $3}
      END {if (!found && c != "") print c}'
}

case "${1:-list}" in
  list)
    tmux list-sessions -F '#{session_name} (#{session_windows} windows)' 2>/dev/null || true
    tmux list-windows -a -F \
      '#{?window_active,*, }#{session_name}:#{window_index}  #{window_name}  #{pane_current_command}  "#{pane_title}"' \
      2>/dev/null || die "no tmux server running"
    ;;
  show)
    [ -n "${2:-}" ] || die "usage: agents-tmux.sh show <name> [lines]"
    name="$2"
    lines="${3:-40}"
    target=$(resolve "$name")
    [ -n "$target" ] || die "no pane named or titled '$name' (try: agents-tmux.sh list)"
    tmux capture-pane -p -S "-${lines}" -t "$target"
    ;;
  *) die "usage: agents-tmux.sh [list | show <name> [lines]]" ;;
esac
