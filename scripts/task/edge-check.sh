#!/usr/bin/env bash
# edge-check.sh — the gate under the resident edge caller: it must make the SAME
# CALL as a one-shot engine invocation, only faster.
#
# Why the call and not the confidence
# -----------------------------------
# needle3 samples, so the same prompt returns different confidences across runs
# (measured 2026-11-02: `list the skills carrying the sops tag` gave 0.6384 and
# 0.9078 in two runs of the same binary and tool set). A gate on the number would
# flake; a gate on the tool name and its argument is the property that matters,
# because those are what the dispatcher executes. Confidence drift is reported, not
# asserted, so a broken calibration stays visible instead of silent.
#
# Why it also measures
# --------------------
# The whole reason the resident process exists is latency, and an untested cache is
# a rumour. So each prompt is timed both ways and the saving is printed.
#
# Exit 0 = every prompt made the same call both ways, 1 = a disagreement or the
# sidecar would not start, 2 = the engine or the graph is unavailable.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
SIDE="$REPO/scripts/task/edge-sidecar.sh"
PROMPTS="$REPO/scripts/task/toolcall-battery.jsonl"
fail=0
ok() { printf 'ok    %s\n' "$1"; }
bad() {
  printf 'FAIL  %s\n' "$1"
  fail=1
}

# The same derivation the dispatcher uses, so the gate tests the real surface.
TOOLS="${EDGE_TOOLS:-}"
if [ -z "$TOOLS" ]; then
  SURFACE_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig-toolcall"
  KEY="$(cat "$REPO"/taskfiles/*.yml "$REPO/lib/taskfile.nix" "$REPO/flake.lock" 2>/dev/null | sha1sum | cut -d' ' -f1)"
  TOOLS="$SURFACE_CACHE_DIR/engine-tools-$KEY.json"
  mkdir -p "$SURFACE_CACHE_DIR"
  if [ ! -s "$TOOLS" ]; then
    nix eval --json ".?submodules=1#taskfileGraph.byName" 2>/dev/null |
      jq '[to_entries[]
           | select(.key | test("^(ops:kg:[a-z]+|ops:ask)$"))
           | select(.value.body | test("vars: \\[[A-Z]"))
           | .key as $n
           | (.value.body | capture("vars: \\[(?<v>[A-Z_, ]+)\\]")) as $c
           | ($c.v | split(",") | map(gsub("^ +| +$"; "")) | map(select(length > 0))) as $vars
           | {name: ($n | gsub(":"; "_")),
              description: (.value.desc // $n | gsub("[[:space:]]+"; " ")),
              parameters: {type: "object",
                           properties: ($vars | map({key: (ascii_downcase), value: {type: "string", description: ("value for " + .)}}) | from_entries),
                           required: ($vars | map(ascii_downcase))}}]' >"$TOOLS" || true
  fi
fi
[ -s "$TOOLS" ] || {
  echo "edge-check: no tool surface (engine-tools json missing)" >&2
  exit 2
}

# EDGE_REQUIRE_UP=1 is the mode the login path runs: the daemon must ALREADY be
# there. The probe is the FIRST thing this script does, because every section
# below can start the caller through the dispatcher — measured 2026-11-02: placed
# after the batch tests, it found a server and reported "already resident" for a
# process the same run had just started, which is exactly the inaudible pass this
# mode exists to remove.
REQUIRE_UP="${EDGE_REQUIRE_UP:-0}"
PID_BEFORE=""
if [ "$REQUIRE_UP" = 1 ]; then
  echo "== resident before the first ask (EDGE_REQUIRE_UP=1) =="
  if st="$("$SIDE" status 2>/dev/null)"; then
    PID_BEFORE="$(jq -r '.pid // ""' <<<"$st")"
    ok "already resident: pid ${PID_BEFORE:-?} on port $(jq -r '.port // "?"' <<<"$st")"
  else
    bad "nothing is listening: EDGE_REQUIRE_UP=1 means the login unit starts this, not the check"
    echo "edge-check: DRIFT — the caller is not resident"
    exit 1
  fi
fi

echo "== the Pareto split, on a fixture =="
# No task in the tree both declares `vars:` and builds, so the heavy exclusion
# would otherwise ship never having fired. This exercises the real classification
# code on a graph that has all three shapes: a light lookup, a build, and a task
# with no arguments to fill.
FIXTURE="$(mktemp)"
trap 'rm -f "$FIXTURE"' EXIT
jq -n '{
  "fixture:light": {body: "desc: Looks up a thing\nrequires:\n  vars: [THING]\ncmds:\n  - echo light\n"},
  "fixture:heavy": {body: "desc: Builds a thing\nrequires:\n  vars: [THING]\ncmds:\n  - nix build .#thing\n"},
  "fixture:novars": {body: "desc: Takes no argument\ncmds:\n  - echo nothing\n"}
}' >"$FIXTURE"
surface="$(TOOLCALL_GRAPH_FILE="$FIXTURE" TOOLCALL_SURFACE='^fixture:' \
  bash "$REPO/scripts/task/toolcall.sh" --list-tools 2>&1 || true)"
echo "$surface" | grep -q 'fixture_light' && ok "a light lookup is on the surface" ||
  bad "the light fixture task was not offered"
echo "$surface" | grep -q 'fixture_heavy' && bad "a task that builds reached the surface" ||
  ok "a task that builds is excluded"
echo "$surface" | grep -q 'excluded.*fixture:heavy' && ok "the exclusion names it" ||
  bad "the excluded task was dropped silently"
echo "$surface" | grep -q 'fixture_novars' && bad "a task with no vars became a tool" ||
  ok "a task with no arguments is not a tool"

echo "== batch stream =="
# The piping contract, gated: N prompts in, N JSON lines out, each carrying its own
# timing and gate. A stream that silently drops a prompt is how a pipeline reports
# success on half the work.
stream="$(printf 'what touches fern\nskills tagged nix\nwhy is the fleet slow\n' |
  bash "$REPO/scripts/task/toolcall.sh" --batch 2>/dev/null || true)"
if [ "$(jq -s 'length' <<<"${stream:-[]}")" = 3 ]; then
  ok "3 prompts in, 3 JSON lines out"
else
  bad "batch emitted $(jq -s 'length' <<<"${stream:-[]}") line(s) for 3 prompts"
fi
if jq -se 'all(.[]; has("n") and has("ms") and has("gate") and has("decision") and has("pareto"))' <<<"${stream:-[]}" >/dev/null; then
  ok "every line carries n, ms, gate, decision and pareto"
else
  bad "a batch line is missing its timing or its verdict"
fi
# Captured, not piped into `grep -q`: grep exits as soon as it matches, the
# producer dies of SIGPIPE, and with pipefail the whole check reads as a failure
# even though the gate fired correctly (measured: exit 141 here).
tiny="$(printf 'what touches fern\n' | TOOLCALL_STEP_S=0.05 bash "$REPO/scripts/task/toolcall.sh" --batch 2>/dev/null || true)"
if grep -q '"gate":"timeout"' <<<"$tiny"; then
  ok "a step over its budget is named, not fatal"
else
  bad "a step over its budget was not reported as a timeout (got: ${tiny:-nothing})"
fi

echo
ENGINE="${NEEDLE_ENGINE:-$(ls -d /nix/store/*-needle-3/bin/needle 2>/dev/null | tail -1)}"
WEIGHTS="${NEEDLE_WEIGHTS:-$(ls /nix/store/*-needle3.cact 2>/dev/null | tail -1)}"
if [ -z "$ENGINE" ] || [ ! -x "$ENGINE" ] || [ -z "$WEIGHTS" ]; then
  echo "edge-check: needle engine or weights not found" >&2
  exit 2
fi

echo "== resident vs one-shot =="
if [ "$REQUIRE_UP" != 1 ]; then
  if ! port="$("$SIDE" ensure "$TOOLS" 2>/dev/null)"; then
    echo "edge-check: the resident caller would not start" >&2
    exit 1
  fi
  ok "resident caller up on port $port"
fi

total=0
same=0
side_ms=0
shot_ms=0

while IFS= read -r line; do
  [ -n "$line" ] || continue
  prompt="$(jq -r '.prompt' <<<"$line")"
  total=$((total + 1))

  t0=${EPOCHREALTIME/./}
  a="$("$SIDE" ask "$TOOLS" "$prompt" 2>/dev/null || true)"
  t1=${EPOCHREALTIME/./}
  side=$(( (t1 - t0) / 1000 ))
  side_ms=$((side_ms + side))

  # The comparison is between the two ENGINE invocations, not the dispatcher: the
  # dispatcher's answer carries the graph-side type repair, so comparing against
  # it would test the repair twice and the caller not at all.
  t2=${EPOCHREALTIME/./}
  b="$(NEEDLE_TELEMETRY=0 DO_NOT_TRACK=1 "$ENGINE" --model "$WEIGHTS" \
    --tools "$TOOLS" --prompt "$prompt" 2>/dev/null || true)"
  t3=${EPOCHREALTIME/./}
  shot=$(( (t3 - t2) / 1000 ))
  shot_ms=$((shot_ms + shot))

  # Compare the CALL: tool name plus the arguments it filled.
  ca="$(jq -c '[.function_calls[]? | {name, arguments}]' <<<"${a:-null}" 2>/dev/null || echo '[]')"
  cb="$(jq -c '[.function_calls[]? | {name, arguments}]' <<<"${b:-null}" 2>/dev/null || echo '[]')"
  confa="$(jq -r '.confidence // 0' <<<"${a:-null}" 2>/dev/null || echo 0)"

  if [ "$ca" = "$cb" ]; then
    same=$((same + 1))
    printf 'ok    %-42s same call  resident %sms / one-shot %sms  conf=%s\n' \
      "$prompt" "$side" "$shot" "$confa"
  else
    bad "$prompt: resident $ca vs one-shot $cb"
  fi
done <"$PROMPTS"

# A require-up run that RESTARTED the server proves the surface the login unit
# booted is not the surface a call asks for — the first call of the session would
# pay a weights load, which is the whole thing the unit exists to prevent.
if [ "$REQUIRE_UP" = 1 ]; then
  if after="$("$SIDE" status 2>/dev/null)" && [ "$(jq -r '.pid // ""' <<<"$after")" = "$PID_BEFORE" ]; then
    ok "same process before and after (the surface did not change under it)"
  else
    bad "the server was replaced mid-run: the login unit booted a different tool surface"
  fi
fi

echo
echo "same call        : $same/$total"
echo "resident mean    : $((side_ms / total)) ms (engine only, via the sidecar)"
echo "one-shot mean    : $((shot_ms / total)) ms (engine only, per invocation)"
echo
if [ "$fail" = 0 ]; then
  echo "edge-check: ok — the resident caller is the same caller, sooner"
else
  echo "edge-check: DRIFT — a resident answer differs from a one-shot answer"
fi
exit "$fail"
