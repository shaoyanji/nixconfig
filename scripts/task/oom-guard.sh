#!/usr/bin/env bash
# oom-guard.sh — run a command on a memory-tight host without taking the machine
# down with it.
#
# WHY THIS EXISTS (measured on frieren, 2026-10-15)
#   `nix flake check` on this 11 GiB NAS evaluates EVERY flake output, not just
#   `checks` — the tail of its own output is "checking flake output
#   'nixosConfigurations' ... checking NixOS configuration
#   'nixosConfigurations.<host>'". 23 NixOS configurations at ~198 MiB of
#   evaluator heap each is ~4.5 GiB, which is what actually happened: 339.78 s
#   wall clock, 6078.5 MiB peak RSS, SIGKILL (exit 137), and the host left at
#   62 % sustained IO-stall (PSI) with 5.4 GiB of swap in use.
#
#   A crashed agent cannot repair the host it crashed, so cleanup of flake/checks.nix
#   is NOT sufficient: the fleet rule is that every evaluation is bounded AND
#   watched. This wrapper does both.
#
#   It does NOT replace the one-host-per-process rule. Peak memory is still
#   O(number of hosts forced by the command), so pass one host at a time.
#
# WATCHDOG (checked every --interval seconds, default 10)
#   * /proc/vmstat oom_kill increases            -> abort, someone was killed
#   * memory PSI full avg10  > MEM_PRESSURE      -> abort, tasks stalling on reclaim
#   * io     PSI full avg10  > IO_PRESSURE       -> abort, storage is the bottleneck
#   * MemAvailable          < MIN_AVAIL_MB       -> abort, about to thrash
#   /proc/vmstat is read directly rather than grepping the journal: it is an
#   exact counter and costs no I/O on a host whose journal is already busy.
#
# USAGE
#   oom-guard.sh [--timeout SECONDS] [--interval SECONDS] [--label TEXT] -- CMD...
#
#   --timeout   wall-clock bound for CMD (default 120; a single host evaluation
#               needs headroom, a leaf `nix eval` does not — pass 3 for those)
#
# EXIT CODES
#   0   command succeeded
#   1   command failed
#   2   watchdog aborted (reason printed; command killed)
#   124 command exceeded --timeout
set -uo pipefail

TIMEOUT=120
INTERVAL=10
LABEL="cmd"
MEM_PRESSURE=${MEM_PRESSURE:-40}
IO_PRESSURE=${IO_PRESSURE:-60}
MIN_AVAIL_MB=${MIN_AVAIL_MB:-400}

while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --label) LABEL="$2"; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done
[ $# -gt 0 ] || { echo "oom-guard: no command given" >&2; exit 1; }

psifull() { # file, want "avg10" of the `full` line
  awk '$1=="full" {for (i=1;i<=NF;i++) if ($i ~ /^avg10=/) {sub(/avg10=/,"",$i); print $i}}' "$1" 2>/dev/null
}
avail_mb() { awk '/^MemAvailable/{print int($2/1024)}' /proc/meminfo 2>/dev/null; }
oom_events() { awk '/^oom_kill/{print $2}' /proc/vmstat 2>/dev/null; }

before_oom=$(oom_events); before_oom=${before_oom:-0}

# Monitor mode puts the job in its OWN process group (pgid == $!), which is what
# makes the measurement honest: `timeout` is the direct child and its own VmHWM is
# ~5 MiB, while the evaluator that actually eats 6 GiB is a grandchild. Sampling
# only $! reported a 4.9 MiB peak for a run that took the host down. With a
# process group we sample every member, and kill the whole group on abort.
set -m
start_ns=$(date +%s%N)
timeout --signal=TERM --kill-after=5 "${TIMEOUT}s" "$@" &
pid=$!
pgid=$pid

peak=0
abort_reason=""
last_check=0

# Peak of the tree: sum of per-process high-water marks over every member of the
# group, maxed over samples. Summing HWM counts shared pages once per process, so
# this is an upper bound rather than an exact figure — for a "is this bounded?"
# gate an over-estimate is the safe direction.
tree_peak_kb() {
  ps -eo pid=,pgid= 2>/dev/null | awk -v g="$pgid" '$2==g{print $1}' |
    while read -r p; do awk '/VmHWM/{print $2}' "/proc/$p/status" 2>/dev/null; done |
    awk '{s+=$1} END{print s+0}'
}

while kill -0 "$pid" 2>/dev/null; do
  v=$(tree_peak_kb)
  if [ -n "${v:-}" ] && [ "$v" -gt "$peak" ]; then peak="$v"; fi

  now=$(date +%s)
  if [ $((now - last_check)) -ge "$INTERVAL" ]; then
    last_check=$now
    now_oom=$(oom_events); now_oom=${now_oom:-0}
    mfull=$(psifull /proc/pressure/memory); mfull=${mfull:-0}
    iofull=$(psifull /proc/pressure/io); iofull=${iofull:-0}
    avail=$(avail_mb); avail=${avail:-9999}

    if [ "$now_oom" -gt "$before_oom" ]; then
      abort_reason="OOM killer fired (/proc/vmstat oom_kill ${before_oom} -> ${now_oom})"
    elif awk -v a="$mfull" -v b="$MEM_PRESSURE" 'BEGIN{exit !(a>b)}'; then
      abort_reason="memory pressure full avg10=${mfull}% > ${MEM_PRESSURE}%"
    elif awk -v a="$iofull" -v b="$IO_PRESSURE" 'BEGIN{exit !(a>b)}'; then
      abort_reason="io pressure full avg10=${iofull}% > ${IO_PRESSURE}%"
    elif [ "$avail" -lt "$MIN_AVAIL_MB" ]; then
      abort_reason="MemAvailable ${avail} MiB < ${MIN_AVAIL_MB} MiB"
    fi

    if [ -n "$abort_reason" ]; then
      # Negative pid = the whole process group, so the evaluator grandchild goes too.
      kill -TERM -- -"$pgid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
      sleep 1
      kill -KILL -- -"$pgid" 2>/dev/null || true
      break
    fi
  fi
  sleep 0.2
done

wait "$pid"; rc=$?
end_ns=$(date +%s%N)

awk -v l="$LABEL" -v s="$start_ns" -v e="$end_ns" -v p="$peak" -v rc="$rc" \
  'BEGIN{printf "%-46s %6.2fs  peak %7.1f MiB  rc=%d\n", l, (e-s)/1e9, p/1024, rc}'

if [ -n "$abort_reason" ]; then
  echo "ABORTED ($LABEL): ${abort_reason}" >&2
  echo "Host protected; the command did not finish. Reduce its scope (one host at a time)" >&2
  exit 2
fi
exit "$rc"
