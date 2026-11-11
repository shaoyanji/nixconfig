#!/usr/bin/env bash
# cpg-loop.sh — one goal, a validated YAML command per turn, executed, fed back.
#
# The model on the other side has no tools, so the loop is the tool: it asks for
# one command at a time in a fixed YAML shape, refuses the command if it is
# destructive, runs it under a timeout in a work directory, and hands the model
# the exit status and the output tail. Sequential by construction — one action,
# one result, one next action — so nothing is spent on a plan that turns out to
# be wrong at step three.
#
# Cost: an answered cpg call moves `usage.dailyQueries.used` by 7 (measured
# 2026-11-11), so the 350/day plan is about 50 real turns, not 350. The loop
# reads the counter before each turn and exits 6 when what is left cannot pay
# for one more call, rather than discovering the wall mid-turn.
#
#   cpg-loop.sh --goal FILE [--steps 6] [--workdir DIR] [--verify CMD]
#               [--state DIR] [--sandbox auto|bwrap|none] [--dry-run]
#   cpg-loop.sh --check-command 'CMD'      # the deny list, no model, no cost
#
# Each turn's answer, in exactly this YAML shape:
#   thought: <one line: what this step is for>
#   run:     <one shell command, one line>
#   expect:  <what output or exit status confirms it worked>
#   stop:    <true|false>
#
# `stop: true` is a request, not a result. The loop exits 0 only when `--verify`
# exits 0 in the work directory; without it the run ends at exit 4 with the goal
# unverified. That is the difference between "the model says it is done" and
# "it is done", and it is the whole reason to have a harness instead of a chat.
#
# Ledger: $STATE/ledger.jsonl, one JSON object per turn, plus $STATE/turn-<n>.yaml
# holding the action as returned. A lock file makes a second run refuse instead
# of interleaving two agents in one work directory.
#
# Exit: 0 verified · 1 call failed · 2 usage · 3 every step refused or no
#       progress · 4 stopped unverified or out of steps · 5 lock held ·
#       6 budget cannot cover another call
set -uo pipefail

MODEL="${MODEL:-claude-haiku-5-5}"
FALLBACK="${FALLBACK:-gpt-6-luna}"
COST_PER_CALL="${COST_PER_CALL:-7}"
STEP_TIMEOUT="${STEP_TIMEOUT:-120}"

usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; }
die() {
  printf 'cpg-loop: %s\n' "$*" >&2
  exit 2
}

# Commands the loop will not run, whatever the model says. This is a floor, not
# a sandbox: it stops the failure that ends a work directory or a host, not a
# clever one.
DENY=(
  'rm[[:space:]]+-[A-Za-z]*[rf]'
  'git[[:space:]]+push'
  'git[[:space:]]+reset[[:space:]]+--hard'
  'git[[:space:]]+clean[[:space:]]+-[A-Za-z]*[fdx]'
  'nixos-rebuild[[:space:]].*(switch|boot)'
  'systemctl[[:space:]].*(stop|restart|disable|mask|kill)'
  '(reboot|shutdown|poweroff|halt)([[:space:]]|$)'
  'mkfs|mke2fs'
  'dd[[:space:]].*of=/dev/'
  '(curl|wget)[^|]*\|[[:space:]]*(ba|z|k)?sh'
  'chmod[[:space:]]+-R[[:space:]]+777'
  '>[[:space:]]*/etc/'
  '>>[[:space:]]*/etc/'
  '>[[:space:]]*/dev/(sd|nvme|vd)'
  '(sops|age)[[:space:]].*(-d|--decrypt)'
  'sudo([[:space:]]|$)|doas([[:space:]]|$)'
  ':[[:space:]]*\([[:space:]]*\)[[:space:]]*\{'
)

refused_reason() { # command -> prints why, returns 0 when refused
  local cmd="$1" p
  for p in "${DENY[@]}"; do
    if printf '%s' "$cmd" | grep -Eqi -- "$p"; then
      printf 'matches the deny list (%s)' "$p"
      return 0
    fi
  done
  case "$cmd" in
    *$'\n'*) printf 'contains a newline; one command per turn'; return 0 ;;
  esac
  if [ "${#cmd}" -gt 4000 ]; then
    printf 'longer than 4000 characters'
    return 0
  fi
  return 1
}

GOAL_FILE="" steps=6 workdir="" verify="" state="" sandbox="auto" dry=0 check_cmd=""

while [ $# -gt 0 ]; do
  case "$1" in
    --goal) GOAL_FILE="${2:?--goal needs a path}"; shift 2 ;;
    --steps) steps="${2:?--steps needs a number}"; shift 2 ;;
    --workdir) workdir="${2:?--workdir needs a path}"; shift 2 ;;
    --verify) verify="${2:?--verify needs a command}"; shift 2 ;;
    --state) state="${2:?--state needs a path}"; shift 2 ;;
    --sandbox) sandbox="${2:?--sandbox needs auto|bwrap|none}"; shift 2 ;;
    --check-command) check_cmd="${2:?--check-command needs a command}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

# The deny list is testable without a model or a prompt.
if [ -n "$check_cmd" ]; then
  if why=$(refused_reason "$check_cmd"); then
    printf 'refused: %s\n' "$why"
    exit 3
  fi
  printf 'allowed\n'
  exit 0
fi

[ -n "$GOAL_FILE" ] || die "--goal is required (see --help)"
[ -f "$GOAL_FILE" ] || die "no such goal file: $GOAL_FILE"
goal=$(cat -- "$GOAL_FILE")
[ -n "$goal" ] || die "goal file is empty"
case "$steps" in
  '' | *[!0-9]*) die "--steps needs a positive integer" ;;
esac
[ "$steps" -ge 1 ] || die "--steps needs a positive integer"

command -v cpg >/dev/null 2>&1 || die "cpg not on PATH"
command -v yq >/dev/null 2>&1 || die "yq not on PATH (the action shape is checked with it)"
command -v jq >/dev/null 2>&1 || die "jq not on PATH"

if [ -z "$workdir" ]; then
  workdir=$(mktemp -d "${TMPDIR:-/tmp}/cpg-loop.XXXXXX")
fi
mkdir -p "$workdir"
workdir=$(cd "$workdir" && pwd)

slug=$(printf '%s' "$goal" | tr -cs 'A-Za-z0-9' '-' | cut -c1-40 | sed -e 's/^-//' -e 's/-$//')
[ -n "$slug" ] || slug=goal
if [ -z "$state" ]; then
  state="${XDG_CACHE_HOME:-$HOME/.cache}/cpg-loop/$slug"
fi
mkdir -p "$state"

lock="$state/lock"
if ! mkdir "$lock" 2>/dev/null; then
  holder=$(cat "$lock/pid" 2>/dev/null || printf 'unknown')
  if kill -0 "$holder" 2>/dev/null; then
    printf 'cpg-loop: another run holds %s (pid %s)\n' "$lock" "$holder" >&2
    exit 5
  fi
  printf 'cpg-loop: clearing a stale lock (pid %s)\n' "$holder" >&2
  rm -rf -- "$lock"
  mkdir "$lock" || die "cannot take $lock"
fi
printf '%s' "$$" >"$lock/pid"
trap 'rm -rf -- "$lock"' EXIT

case "$sandbox" in
  auto)
    if command -v bwrap >/dev/null 2>&1; then sandbox=bwrap; else sandbox=none; fi
    ;;
  bwrap)
    command -v bwrap >/dev/null 2>&1 || die "--sandbox bwrap but bwrap is not installed"
    ;;
  none) ;;
  *) die "--sandbox takes auto, bwrap or none" ;;
esac

remaining() { cpg usage --json 2>/dev/null | jq -r '.usage.dailyQueries.remaining // empty'; }

run_step() { # cmd, outfile
  local cmd="$1" out="$2"
  if [ "$sandbox" = bwrap ]; then
    (cd "$workdir" && timeout "$STEP_TIMEOUT" bwrap --dev-bind / / --chdir "$workdir" \
      --unshare-pid --die-with-parent \
      env -i PATH="$PATH" HOME="$HOME" LANG=C TERM=dumb bash -c "$cmd") >"$out" 2>&1
  else
    (cd "$workdir" && timeout "$STEP_TIMEOUT" \
      env -i PATH="$PATH" HOME="$HOME" LANG=C TERM=dumb bash -c "$cmd") >"$out" 2>&1
  fi
}

ledger="$state/ledger.jsonl"
: >>"$ledger"
last_cmd=""
repeats=0
refusals=0
turn=0

ledger_text() {
  if [ ! -s "$ledger" ]; then
    printf '(no steps yet)'
    return
  fi
  tail -n 6 "$ledger" |
    jq -rs '.[] | "step \(.turn): \(.note // "ran")\n  cmd: \(.cmd // "")\n  exit: \(.exit // "n/a")\n  output: \(.out_tail // "")"' |
    cut -c1-2500
}

turn_packet() {
  local history
  history=$(ledger_text)
  cat <<EOF
You are one step in a loop that has a shell and nothing else. You cannot read
the repository or browse: the goal and the step results below are the whole
world you know. One command per turn; the loop runs it and reports back.

GOAL:
$goal

WORK DIRECTORY: $workdir
STEPS SO FAR:
$history

Return ONLY YAML, no fence and no prose, in exactly this shape:

thought: <one line: what this step is for>
run: <one shell command, one line, no heredoc, nothing interactive>
expect: <what output or exit status would confirm it worked>
stop: <true|false>

Rules: prefer a command that reads over one that writes; never run anything that
deletes, pushes, restarts a service, decrypts a secret or needs sudo (the harness
refuses it and says so); if the last step failed, change the command instead of
repeating it; when the goal is already met, set stop: true and do not invent more
work.
EOF
}

strip() { sed -e 's/\x1b\[[0-9;?]*[a-zA-Z]//g' -e 's/\r//g'; }

call_model() { # packet -> reply on stdout
  local packet="$1" model raw rc reply
  for model in "$MODEL" "$FALLBACK"; do
    [ -n "$model" ] || continue
    rc=0
    raw=$(cpg chat -m "$model" -s "$slug-t$turn" "$packet" 2>&1) || rc=$?
    reply=$(printf '%s' "$raw" | strip)
    if [ "$rc" -eq 0 ] && [ -n "$(printf '%s' "$reply" | tr -d '[:space:]')" ]; then
      [ "$model" = "$MODEL" ] || printf 'cpg-loop: %s did not answer, %s did\n' "$MODEL" "$model" >&2
      printf '%s\n' "$reply"
      return 0
    fi
    printf 'cpg-loop: %s failed: %s\n' "$model" "$(printf '%s' "$reply" | tail -3)" >&2
  done
  return 1
}

record() { # json fields appended by jq
  printf '%s\n' "$1" >>"$ledger"
}

if [ "$dry" -eq 1 ]; then
  turn_packet
  printf 'cpg-loop: dry run, model=%s sandbox=%s workdir=%s steps=%s, nothing sent\n' \
    "$MODEL" "$sandbox" "$workdir" "$steps" >&2
  exit 0
fi

while [ "$turn" -lt "$steps" ]; do
  turn=$((turn + 1))

  left=$(remaining)
  if [ -n "$left" ] && [ "$left" -lt "$COST_PER_CALL" ]; then
    printf 'cpg-loop: %s queries left and one call costs about %s — stopping\n' "$left" "$COST_PER_CALL" >&2
    exit 6
  fi

  packet=$(turn_packet)
  reply=$(call_model "$packet") || exit 1
  action=$(printf '%s\n' "$reply" | bash "$(dirname "$0")/llm-yaml.sh" --map 2>/dev/null) || action=""

  shape_error=""
  if [ -z "$action" ]; then
    shape_error="the reply is not parseable YAML"
  elif ! yq -e '(.run | type) == "!!str" and (.run | length) > 0 and (.thought | type) == "!!str" and (.expect | type) == "!!str" and (.stop | tag) != "!!null"' \
    >/dev/null 2>&1 <<<"$action"; then
    shape_error="the YAML does not have thought/run/expect/stop"
  fi

  printf '%s\n' "$action" >"$state/turn-$turn.yaml"

  if [ -n "$shape_error" ]; then
    printf 'cpg-loop: turn %s: %s\n' "$turn" "$shape_error" >&2
    record "$(jq -nc --argjson turn "$turn" --arg err "$shape_error" \
      --arg raw "$(printf '%s' "$reply" | head -c 800)" \
      '{turn: $turn, note: "action rejected", shape_error: $err, raw: $raw}')"
    continue
  fi

  cmd=$(yq -r '.run' <<<"$action")
  thought=$(yq -r '.thought' <<<"$action")
  stop_req=$(yq -r '.stop' <<<"$action" | tr '[:upper:]' '[:lower:]')

  if why=$(refused_reason "$cmd"); then
    refusals=$((refusals + 1))
    printf 'cpg-loop: turn %s refused: %s\n' "$turn" "$why" >&2
    record "$(jq -nc --argjson turn "$turn" --arg cmd "$cmd" --arg why "$why" --arg thought "$thought" \
      '{turn: $turn, note: "refused", cmd: $cmd, refused: $why, thought: $thought}')"
    if [ "$refusals" -ge "$steps" ]; then
      printf 'cpg-loop: every step so far was refused; the goal may not be reachable under the deny list\n' >&2
      exit 3
    fi
    continue
  fi

  if [ "$cmd" = "$last_cmd" ]; then
    repeats=$((repeats + 1))
    printf 'cpg-loop: turn %s repeated the previous command\n' "$turn" >&2
    record "$(jq -nc --argjson turn "$turn" --arg cmd "$cmd" \
      '{turn: $turn, note: "repeated the previous command; not run", cmd: $cmd}')"
    if [ "$repeats" -ge 2 ]; then
      printf 'cpg-loop: two repeats in a row; the loop is not making progress\n' >&2
      exit 3
    fi
    continue
  fi
  last_cmd="$cmd"

  out="$state/turn-$turn.out"
  printf 'cpg-loop: turn %s/%s: %s\n' "$turn" "$steps" "$cmd" >&2
  rc=0
  run_step "$cmd" "$out" || rc=$?
  tail_text=$(tail -c 1500 "$out" 2>/dev/null | tr -d '\000')

  record "$(jq -nc --argjson turn "$turn" --arg cmd "$cmd" --arg thought "$thought" \
    --argjson exit "$rc" --arg out "$tail_text" --arg stop "$stop_req" \
    '{turn: $turn, cmd: $cmd, thought: $thought, exit: $exit, out_tail: $out, stop_requested: ($stop == "true" or $stop == "yes")}')"

  if [ "$stop_req" = "true" ] || [ "$stop_req" = "yes" ]; then
    if [ -z "$verify" ]; then
      printf 'cpg-loop: the model says the goal is met, but no --verify was given\n' >&2
      printf 'cpg-loop: goal unverified; the last %s turn(s) are in %s\n' "$turn" "$ledger" >&2
      exit 4
    fi
    printf 'cpg-loop: verifying: %s\n' "$verify" >&2
    vrc=0
    run_step "$verify" "$state/verify.out" || vrc=$?
    if [ "$vrc" -eq 0 ]; then
      printf 'cpg-loop: verified after %s turn(s); output in %s\n' "$turn" "$state" >&2
      exit 0
    fi
    printf 'cpg-loop: verify failed (exit %s); feeding that back\n' "$vrc" >&2
    record "$(jq -nc --argjson turn "$turn" --argjson exit "$vrc" \
      --arg out "$(tail -c 1000 "$state/verify.out" 2>/dev/null)" \
      '{turn: ($turn + 0.5), note: "verify failed", exit: $exit, out_tail: $out}')"
  fi
done

printf 'cpg-loop: steps exhausted (%s) with the goal unverified; ledger: %s\n' "$steps" "$ledger" >&2
exit 4
