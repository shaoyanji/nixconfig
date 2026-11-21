#!/usr/bin/env bash
# xs-idle-watch — poll tmux pane idle times and ping Telegram when an agent
# pane goes idle past the threshold. Zero traffic when nothing is idle.
#
# State: $HOME/.local/state/xs-idle-watch/last.<pane> = last idle-seen epoch per pane,
# so we ping once per idle spell, not every tick.
#
# Idle time is derived from the pane tty's mtime (tmux's `pane_idle` format field
# returns empty in tmux 3.8, so tty mtime is the fallback: last write/read on the
# pty = last activity).
set -euo pipefail

IDLE_SECS="${IDLE_SECS:-300}"          # ping when a pane is idle this long
STATE_DIR="${STATE_DIR:-$HOME/.local/state/xs-idle-watch}"
BOT_TOKEN_FILE="${BOT_TOKEN_FILE:-$HOME/.config/hermes/hermes.env}"
CHAT_ID="${TELEGRAM_CHAT_ID:-8679391100}"

mkdir -p "$STATE_DIR"

# Determine tmux invocation: systemd user services don't inherit TMUX.
# `tmux -L default` works where `TMUX=<full socket path>` does not.
if [ -z "${TMUX:-}" ]; then
  TMUX_CMD=(tmux -L default)
else
  TMUX_CMD=(tmux)
fi

now=$(date +%s)
pinged=0

# Bot token: prefer environment (from hermes.env), fall back to token file.
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
if [ -z "$BOT_TOKEN" ]; then
  if [ ! -r "$BOT_TOKEN_FILE" ]; then
    echo "xs-idle-watch: bot token not set and $BOT_TOKEN_FILE not readable" >&2
    exit 3
  fi
  BOT_TOKEN="$(grep '^TELEGRAM_BOT_TOKEN=' "$BOT_TOKEN_FILE" | cut -d= -f2 | tr -d '"' | tr -d '\r\n ')"
fi

PANES_FILE=$(mktemp)
trap 'rm -f "$PANES_FILE"' EXIT

"${TMUX_CMD[@]}" list-panes -a -F \
  '#{session_name}:#{window_index}.#{pane_index}|#{pane_title}|#{pane_current_command}|#{pane_tty}' \
  2>/dev/null > "$PANES_FILE" || true

while IFS='|' read -r sel title cmd tty; do
  [ -n "$sel" ] || continue
  [ -n "$tty" ] || continue
  # Idle seconds = now - tty mtime (last activity on the pty).
  mtime=$(stat -c %Y "$tty" 2>/dev/null || echo 0)
  idle_secs=$(( now - mtime ))
  if [ "$idle_secs" -lt "$IDLE_SECS" ]; then
    continue
  fi
  state_file="$STATE_DIR/last.$(printf '%s' "$sel" | tr '/:' '__')"
  last_seen=0
  [ -r "$state_file" ] && last_seen="$(cat "$state_file")"
  if [ "$last_seen" -ge "$idle_secs" ]; then
    continue
  fi
  printf '%s' "$idle_secs" > "$state_file"
  mins=$(( idle_secs / 60 ))
  text="idle agent pane: $sel ($title) — $cmd idle ${mins}m"
  payload=$(jq -cn --arg chat_id "$CHAT_ID" --arg text "$text" '{chat_id: ($chat_id | tonumber), text: $text}')
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
    -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -H 'Content-Type: application/json' -d "$payload" 2>/dev/null || echo 000)
  if [ "$code" = "200" ]; then
    echo "xs-idle-watch: pinged for $sel (${mins}m idle)"
    pinged=$((pinged + 1))
  else
    echo "xs-idle-watch: Telegram HTTP $code for $sel" >&2
  fi
done < "$PANES_FILE"

# Reap state for panes that no longer exist
LIVE_FILE=$(mktemp)
"${TMUX_CMD[@]}" list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}' \
  2>/dev/null | tr '/:' '__' > "$LIVE_FILE" || true
for f in "$STATE_DIR"/last.*; do
  [ -e "$f" ] || continue
  key="$(basename "$f" | sed 's/^last\.//')"
  if ! grep -qF "$key" "$LIVE_FILE"; then
    rm -f "$f"
  fi
done
rm -f "$LIVE_FILE"

echo "xs-idle-watch: scan done, $pinged ping(s)"
