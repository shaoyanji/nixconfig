#!/usr/bin/env bash
# Long tasks, without the long timeout.
#
# A rebuild is minutes of work, so blocking a caller on it is the wrong shape:
# whoever waits sets a timeout, and a timeout is a guess that is either too short
# (killed work) or dead time (waiting on nothing). This runs the command in its
# own tmux server, records the exit code, and lets the caller ask — cheaply, at
# any moment — "is it done, and how did it end?".
#
# Contract (one exit code per question, so a summary can promise it):
#   start  <cmd...>            0 launched · 1 launch failed · 2 state unwritable
#   status [id]                0 exited 0 · 1 exited non-zero · 3 still running · 2 unknown id
#   wait   [id] [--timeout S]  same as status; 3 also means the wait timed out
#   logs   [id]                0 printed · 2 unknown id
#   stop   [id]                0 no longer running · 2 unknown id
#   prune                      0 always
#
# Table mode (`status` with no id) is a READ: it always exits 0 and prints one
# NUDGE line per job that finished since the last read, then clears them, so the
# nudge arrives exactly once.
set -u

state="${XDG_STATE_HOME:-$HOME/.local/state}/nixconfig-jobs"
# A dedicated tmux server: the operator's own session is never touched, and
# `tmux ls` in their shell does not grow a job every rebuild.
sock="nixjobs"

die() {
  echo "job: $*" >&2
  exit "${2:-1}"
}

need_tmux() {
  command -v tmux >/dev/null 2>&1 || die "tmux not on PATH; this runner is tmux-backed on purpose (a bare '&' freezes in a tool shell)"
}

job_dir() {
  [ -n "${1:-}" ] || return 1
  [ -d "$state/$1" ] || return 1
  printf '%s\n' "$state/$1"
}

# The newest job, by the epoch prefix every id carries. Used when no id is given
# so the common case ("the thing I just started") needs no copy-paste.
newest() {
  ls -1 "$state" 2>/dev/null | grep -E '^[0-9]+-' | sort -n | tail -n1
}

resolve() {
  local id="${1:-}"
  if [ -z "$id" ]; then
    id="$(newest)"
    if [ -z "$id" ]; then
      echo "job: no jobs yet — start one with: task infra:job:start TASK=<task>" >&2
      return 2
    fi
  fi
  if ! job_dir "$id" >/dev/null; then
    echo "job: unknown job id: $id (try: task infra:job:status)" >&2
    return 2
  fi
  printf '%s\n' "$id"
}

rc_of() {
  local d
  d="$(job_dir "$1")" || return 1
  [ -f "$d/exit" ] || return 1
  printf '%s\n' "$(cat "$d/exit")"
}

# A stopped job has no exit code — the command never returned. It is not
# "running" (nothing is working) and not a clean exit, so it gets its own state
# instead of a fabricated code.
state_of() {
  local d
  d="$(job_dir "$1")" || {
    echo missing
    return
  }
  if [ -f "$d/exit" ]; then
    echo "exited:$(cat "$d/exit")"
  elif [ -f "$d/stopped" ]; then
    echo stopped
  elif running "$1"; then
    echo running
  else
    # No exit code and no session: the job died with its host, not by finishing.
    echo lost
  fi
}

running() {
  tmux -L "$sock" has-session -t "job-$1" 2>/dev/null
}

cmd_start() {
  [ "$#" -gt 0 ] || die "usage: job.sh start <command> [args...]"
  need_tmux
  mkdir -p "$state" 2>/dev/null || die "cannot create $state" 2

  local a id slug
  slug="$(printf '%s' "$*" | tr -cs '[:alnum:]' '-' | sed 's/^-//; s/-$//' | cut -c1-40)"
  id="$(date +%s)-${slug:-job}"

  local d="$state/$id"
  mkdir -p "$d" || die "cannot create $d" 2
  printf '%s\n' "$*" >"$d/cmd"
  date -Is >"$d/started"

  # The runner is a file, not a quoted one-liner: tmux hands a one-liner to a
  # shell, which re-splits it. `start` therefore takes an argv, not shell syntax,
  # and every word is quoted back out with %q so nothing is ever re-interpreted.
  local quoted
  quoted=""
  for a in "$@"; do quoted+="$(printf '%q ' "$a")"; done
  cat >"$d/run.sh" <<RUN
#!/usr/bin/env bash
set -u
# /run/wrappers/bin FIRST: `sudo` there is NixOS's setuid wrapper, while
# /run/current-system/sw/bin/sudo is a plain symlink into the store. With the
# store path ahead of the wrapper, every sudo in a job died with "must be owned
# by uid 0 and have the setuid bit set" — including infra:rebuild:nixos.
export PATH="/run/wrappers/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:\$PATH"
cd "${JOB_CWD:-$PWD}" || exit 2
set -o pipefail
${quoted}2>&1 | tee -a "$d/log"
rc=\${PIPESTATUS[0]}
printf '%s\n' "\$rc" >"$d/exit"
printf '%s\t%s\t%s\n' "\$(date +%s)" "$id" "\$rc" >>"$state/pending" 2>/dev/null
if command -v notify-send >/dev/null 2>&1; then
  if [ "\$rc" = 0 ]; then
    notify-send -a nixconfig "job $id" "finished clean" >/dev/null 2>&1 || true
  else
    notify-send -a nixconfig -u critical "job $id" "FAILED (exit \$rc) — task infra:job:logs" >/dev/null 2>&1 || true
  fi
fi
exit "\$rc"
RUN
  chmod +x "$d/run.sh"

  tmux -L "$sock" new-session -d -s "job-$id" "bash '$d/run.sh'" 2>/dev/null ||
    die "tmux refused to start the session (try: tmux -L $sock ls)"

  echo "job $id started"
  echo "  log     $d/log"
  echo "  follow  task infra:job:logs ID=$id"
  echo "  status  task infra:job:status            (exit code when it ends)"
}

cmd_status() {
  if [ "$#" -gt 0 ]; then
    local id st
    id="$(resolve "$1")" || exit 2
    st="$(state_of "$id")"
    case "$st" in
      exited:*)
        echo "job $id exited ${st#exited:}"
        [ "${st#exited:}" = 0 ] || return 1
        return 0
        ;;
      stopped)
        echo "job $id was stopped — it never returned, so there is no exit code"
        return 1
        ;;
      lost)
        echo "job $id has no exit code and no session left (the host went down under it?)"
        return 1
        ;;
      *)
        echo "job $id still running"
        return 3
        ;;
    esac
  fi

  # Read-only table + one-shot nudge.
  local any=0
  while IFS=$'\t' read -r _ts nid nrc; do
    [ -n "${nid:-}" ] || continue
    if [ "$nrc" = 0 ]; then
      echo "NUDGE job $nid exited 0 (clean)"
    else
      echo "NUDGE job $nid exited $nrc — read it: task infra:job:logs ID=$nid"
    fi
  done <"$state/pending" 2>/dev/null
  : >"$state/pending" 2>/dev/null || true

  printf '%-28s %-9s %-5s %s\n' ID STATE EXIT COMMAND
  local id dir st ex
  for dir in "$state"/*/; do
    [ -d "$dir" ] || continue
    any=1
    id="$(basename "$dir")"
    ex='-'
    st="$(state_of "$id")"
    case "$st" in
      exited:*) ex="${st#exited:}"; st=exited ;;
    esac
    printf '%-28s %-9s %-5s %s\n' "$id" "$st" "$ex" "$(head -n1 "$dir/cmd" 2>/dev/null | cut -c1-60)"
  done
  [ "$any" = 1 ] || echo '(no jobs — task infra:job:start TASK=<task>)'
  return 0
}

cmd_wait() {
  local id="" timeout=600
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --timeout) timeout="${2:-600}"; shift 2 ;;
      --timeout=*) timeout="${1#*=}"; shift ;;
      *) id="$1"; shift ;;
    esac
  done
  case "$timeout" in *[!0-9]* | '') die "--timeout wants whole seconds, got '$timeout'" 1 ;; esac
  id="$(resolve "$id")" || exit 2
  local deadline=$(( $(date +%s) + timeout )) rc st
  while :; do
    st="$(state_of "$id")"
    case "$st" in
      exited:*)
        rc="${st#exited:}"
        echo "job $id exited $rc after $(( $(date +%s) - $(stat -c %Y "$state/$id/started" 2>/dev/null || date +%s) ))s"
        [ "$rc" = 0 ] || return 1
        return 0
        ;;
      stopped)
        echo "job $id was stopped before it finished"
        return 1
        ;;
      lost)
        echo "job $id lost its session without an exit code"
        return 1
        ;;
    esac
    if [ "$(date +%s)" -ge "$deadline" ]; then
      echo "job $id still running after ${timeout}s — it is not lost, it is working: task infra:job:status ID=$id" >&2
      return 3
    fi
    sleep 2
  done
}

cmd_logs() {
  local id d
  id="$(resolve "${1:-}")" || exit 2
  d="$(job_dir "$id")"
  echo "== $id: $(head -n1 "$d/cmd") =="
  tail -n "${LINES:-40}" "$d/log" 2>/dev/null || echo '(no output yet)'
}

cmd_stop() {
  local id
  id="$(resolve "${1:-}")" || exit 2
  if [ -f "$state/$id/exit" ]; then
    echo "job $id had already exited $(cat "$state/$id/exit"); nothing to stop"
    return 0
  fi
  tmux -L "$sock" kill-session -t "job-$id" 2>/dev/null || true
  if running "$id"; then
    die "session for $id survived kill-session" 1
  fi
  date -Is >"$state/$id/stopped"
  echo "job $id stopped"
}

cmd_prune() {
  local days="${1:-7}" dir id
  for dir in "$state"/*/; do
    [ -d "$dir" ] || continue
    id="$(basename "$dir")"
    running "$id" && continue
    if [ -n "$(find "$dir" -maxdepth 0 -mtime "+$days" 2>/dev/null)" ]; then
      rm -rf "$dir"
      echo "pruned $id"
    fi
  done
  # A pending line whose job is gone would nudge forever.
  [ -f "$state/pending" ] || return 0
  local tmp; tmp="$(mktemp)"
  while IFS=$'\t' read -r ts nid nrc; do
    [ -d "$state/$nid" ] && printf '%s\t%s\t%s\n' "$ts" "$nid" "$nrc" >>"$tmp"
  done <"$state/pending"
  mv "$tmp" "$state/pending"
}

case "${1:-status}" in
  start) shift; cmd_start "$@" ;;
  status | list) shift; cmd_status "$@" ;;
  wait) shift; cmd_wait "$@" ;;
  logs | tail) shift; cmd_logs "$@" ;;
  stop | kill) shift; cmd_stop "$@" ;;
  prune) shift; cmd_prune "$@" ;;
  *)
    echo "usage: job.sh {start <cmd...>|status [id]|wait [id] [--timeout S]|logs [id]|stop [id]|prune [days]}" >&2
    exit 1
    ;;
esac
rc=$?

# Literal exits, not `exit $rc`: a task summary that promises a code is checked
# against the codes this file literally emits, so the contract has to be spelled
# out here or it cannot be verified.
case "$rc" in
  0) exit 0 ;;
  1) exit 1 ;;
  2) exit 2 ;;
  3) exit 3 ;;
  *) exit 1 ;;
esac
