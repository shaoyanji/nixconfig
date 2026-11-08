#!/usr/bin/env bash
# toolcall.sh — needle3 as the CALLER, the task graph as its tool set, and a
# calibrated confidence gate between "acted" and "ask a reasoning model".
#
# Why this shape
# --------------
# Needle 3 is an 8-29 MB on-device tool caller. Its output is one JSON object with
# `function_calls`, a `reasoning` line and a CALIBRATED `confidence` head, and a
# request no tool covers returns an empty call list rather than a guess
# (cactus-compute/needle, 2026-11). That is a dispatcher, not a reasoner — so the
# cheap thing must run first and the expensive thing must be the FALLBACK.
#
# The tool set is NOT hand written here: it is derived from the compiled task
# graph (`scripts/task/lib/taskfile_graph.py by-name`), so a tool exists exactly when a task exists and
# every tool name maps back to a runnable `task <name>`. A model that invents a
# tool is rejected, not executed (see `--list-tools` for the current surface).
#
# The gate is four outcomes, because a single threshold is how a caller becomes
# either useless (too strict) or dangerous (too loose):
#
#   READ-ONLY tool          any validated call -> run it, prefetch       (exit 0)
#   confidence >= ACT       one validated call -> run the task          (exit 0)
#   CONFIRM <= c < ACT      a real candidate, not certain -> show it    (exit 3)
#   c < CONFIRM, or empty   no answer -> hand back a structured error   (exit 2)
#
# The prefetch band exists because the confidence head is honest and often low:
# measured 2026-11-02, four of six real prompts came back below 0.1 even when the
# tool and the argument were right. For a graph lookup that does not matter — the
# query is read-only, costs ~30 ms, and returns the question's neighbourhood, so
# running it is cheaper than a reasoning round that would issue the same call.
# The allowlist is a prefix (`ops:kg:`, `ops:ask`), NOT a deny-list of mutating
# verbs, so a task added to the surface later (infra:deploy:*, dev:git:*) is gated
# by construction rather than by someone remembering to classify it.
#
# Output is TOON by default (the agent IR: `context[7]` costs a fraction of the
# same JSON array) and JSON under --json, for programs.
#
# Measured on delphi (2026-11-02, 6 tools): "what touches fern" came back
# `kg_skill(skill=fern)` at confidence 0.5899 — the WRONG tool, in the confirm
# band. That is the case this file exists for: without the band it would have been
# executed, and without validation it would have run a task named by the model.
#
# Usage
#   toolcall.sh --prompt "what touches fern" [--dry-run]
#   toolcall.sh --list-tools
#   toolcall.sh --prompt "..." --act 0.9 --confirm 0.6
#   TOOLCALL_SINGLE=1 toolcall.sh --prompt "..."   # one tool: entity only
#
# Exit: 0 = acted (or would act, with --dry-run), 1 = harness unavailable (engine,
# weights or graph missing), 2 = fall back to a reasoning model, 3 = needs
# confirmation. Distinct codes because "no opinion" and "the tool is missing" are
# different failures and a caller must be able to tell them apart.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
# Definitions only — the graph is resolved inside the repair branch, so a call
# that needs no repair never pays for it.
. "$REPO/scripts/task/lib/kg-graph.sh"
# The declared call surface: prefixes over the task graph. This is the one place a
# new family of callable tasks is added, and the graph decides which ones exist.
SURFACE="${TOOLCALL_SURFACE:-^(ops:kg:[a-z]+|ops:ask|checks:host|infra:plan:host:[a-z]+)$}"

ACT="${TOOLCALL_ACT:-0.85}"
CONFIRM="${TOOLCALL_CONFIRM:-0.55}"
PROMPT=""
DRY_RUN=0
BATCH=0
LIST=0
TOOLSPATH=0
MODE="${TOOLCALL_FORMAT:-toon}"

while [ $# -gt 0 ]; do
  case "$1" in
  --prompt | -p)
    PROMPT="${2:-}"
    shift
    ;;
  --act)
    ACT="${2:-}"
    shift
    ;;
  --confirm)
    CONFIRM="${2:-}"
    shift
    ;;
  --dry-run) DRY_RUN=1 ;;
  --batch | --stream) BATCH=1 ;;
  --list-tools) LIST=1 ;;
  --tools-path) TOOLSPATH=1 ;;
  --human | --toon) MODE=toon ;;
  --json) MODE=json ;;
  -h | --help)
    sed -n '2,42p' "$0"
    exit 0
    ;;
  *)
    echo "unknown argument: $1" >&2
    exit 1
    ;;
  esac
  shift
done

# The tool surface is compiled from those sources, so it is cached against their
# CONTENT, not against "is the tree dirty": one compile here is ~600 ms on every
# call, which is more than the lookup it enables. Keyed on the files the compiler
# reads (taskfiles/*.yml + the compiler + the flake lock), so an edit misses and
# every other call in a loop hits. TOOLCALL_REFRESH=1 skips the cache.
SURFACE_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig-toolcall"
# Computed in the parent shell: load_graph runs inside `$( )`, so anything it
# assigns is gone by the time the caller needs it (TOOLS_FILE does).
SURFACE_KEY="$(cat "$REPO"/taskfiles/*.yml "$REPO/scripts/task/lib/taskfile_graph.py" "$REPO/flake.lock" 2>/dev/null | sha1sum | cut -d' ' -f1)"
SURFACE_CACHE="$SURFACE_CACHE_DIR/surface-$SURFACE_KEY.json"
load_graph() {
  if [ -z "${TOOLCALL_REFRESH:-}" ] && [ -s "$SURFACE_CACHE" ]; then
    cat "$SURFACE_CACHE"
    return 0
  fi
  python3 "$REPO/scripts/task/lib/taskfile_graph.py" by-name 2>/dev/null | {
    if ! out="$(cat)" || [ -z "$out" ]; then return 1; fi
    mkdir -p "$SURFACE_CACHE_DIR"
    printf '%s' "$out" >"$SURFACE_CACHE.tmp" && mv "$SURFACE_CACHE.tmp" "$SURFACE_CACHE"
    # Bounded, like the graph cache: one entry per content state, newest 20 kept.
    # No `xargs`: the login unit's PATH is a bounded makeBinPath, and `xargs`
    # lives in findutils, so the prune died with "command not found" and the
    # cache silently grew (measured 2026-11-02, in the unit's journal).
    ls -1t "$SURFACE_CACHE_DIR"/surface-*.json 2>/dev/null | tail -n +21 |
      while IFS= read -r old; do rm -f -- "$old"; done
    printf '%s' "$out"
  }
}

# A fixture graph, so the surface rules can be tested on the cases the real tree
# does not happen to contain (today: no task both declares `vars:` and builds,
# so the heavy exclusion would ship unexercised).
if [ -n "${TOOLCALL_GRAPH_FILE:-}" ]; then
  GRAPH="$(cat "$TOOLCALL_GRAPH_FILE")"
else
  GRAPH="$(load_graph)" || {
    echo "toolcall: the task graph did not evaluate" >&2
    exit 1
  }
fi

# The Pareto split, applied to the TOOLS rather than to a sentence about them.
# needle3 is for the quadrant that is small AND non-reducible — one deterministic
# lookup whose answer is a value or a set it need not decompose. Anything that can
# BUILD is large and belongs to a reasoning agent that budgets it, so a heavy verb
# in the body removes a task from the surface no matter what pattern it matches.
# (Derived from the body, not from a hand-kept list: the day someone adds
# `checks:host` to SURFACE, it is excluded by its `nix build`, not by memory.)
HEAVY_RE='nix build|nix-build|nixos-rebuild|darwin-rebuild|home-manager switch|nix flake check|disko|nix develop|make install'

# A task is a tool when its name is on the call surface AND it declares
# `requires.vars`: a tool with no arguments cannot fill anything, so it is not a
# call target. (The parameter surface is read as data, not as `vars: [X]` text.)
SURFACE_ALL="$(jq -c --arg re "$SURFACE" --arg heavy "$HEAVY_RE" '
  to_entries
  | map(select(.key | test($re)))
  | map(select((.value.params // []) | length > 0))
  | map({task: .key, heavy: (.value.body | test($heavy; "i"))})
' <<<"$GRAPH")"
HEAVY_TASKS="$(jq -r '[.[] | select(.heavy) | .task] | join(",")' <<<"$SURFACE_ALL")"

TOOLS="$(jq -c --arg re "$SURFACE" --arg heavy "$HEAVY_RE" '
  to_entries
  | map(select(.key | test($re)))
  | map(select((.value.params // []) | length > 0))
  | map(select(.value.body | test($heavy; "i") | not))
  | map(.key as $name
      | (.value.params) as $vars
      | {
          name: ($name | gsub(":"; "_")),
          task: $name,
          # `desc` ONLY. Measured 2026-11-02: (desc + 400 chars of summary) dropped
          # the same query from 0.59 to 0.01 — a 29M caller has no room for prose,
          # and the summary restates the task instead of naming the trigger.
          description: (.value.desc // .key | gsub("[[:space:]]+"; " ")),
          parameters: {
            type: "object",
            properties: ($vars | map({key: (ascii_downcase), value: {type: "string", description: ("value for " + .)}}) | from_entries),
            required: ($vars | map(ascii_downcase))
          }
        })
' <<<"$GRAPH")"

COUNT="$(jq 'length' <<<"$TOOLS")"
if [ "$COUNT" -eq 0 ]; then
  echo "toolcall: the call surface matched no task with vars (surface: $SURFACE)" >&2
  exit 1
fi

if [ "$LIST" = 1 ]; then
  jq -r '.[] | "\(.name) -> task \(.task)  [\(.parameters.required | join(","))]"' <<<"$TOOLS"
  # Named, not silently dropped: a task that matched the surface and lost to the
  # Pareto rule is exactly the thing someone will wonder about.
  if [ -n "$HEAVY_TASKS" ]; then
    printf 'excluded (large: builds, so a reasoning agent budgets it): %s\n' "$HEAVY_TASKS"
  fi
  exit 0
fi

# A STABLE path, keyed by the surface: the resident sidecar compares this file's
# hash to the surface it booted with, so a temp name would restart it every call.
# Written once per surface, not once per call (the derivation is 38 ms). This is
# also the ONE derivation of the engine's tool set: `--tools-path` lets the login
# unit come up on exactly the surface a call will use, instead of a second copy of
# the filter that could drift from this one.
TOOLS_FILE="$SURFACE_CACHE_DIR/engine-tools-$SURFACE_KEY.json"
# The engine wants {name, description, parameters}; `task` is ours and is stripped.
if [ ! -s "$TOOLS_FILE" ]; then
  jq '[.[] | {name, description, parameters}]' <<<"$TOOLS" >"$TOOLS_FILE" 2>/dev/null || true
fi
if [ "$TOOLSPATH" = 1 ]; then
  printf '%s\n' "$TOOLS_FILE"
  exit 0
fi

# --- batch: many prompts, one process, one JSON line each ---------------------
# The alternative it replaces is a caller wrapping a long pipeline in `timeout`,
# which cannot say WHICH step was slow and kills the whole run to punish one. Here
# each step is its own bounded call (read-only lookups, or a pre-engine refusal),
# timed, gate-checked and emitted as NDJSON, so `| jq` and a per-step timing gate
# are the interface. stdout stays pure JSON: the summary goes to stderr, and the
# exit code is the gate (0 = every step resolved or escalated, 1 = a step failed,
# timed out, or the harness broke).
if [ "${BATCH:-0}" = 1 ]; then
  STEP="${TOOLCALL_STEP_S:-20}"
  n=0
  total_ms=0
  worst=0
  while IFS= read -r raw || [ -n "$raw" ]; do
    case "$raw" in *[![:space:]]*) ;; *) continue ;; esac
    n=$((n + 1))
    case "$raw" in
    '{'*) prompt="$(jq -r '.prompt // .Q // empty' <<<"$raw" 2>/dev/null || true)" ;;
    *) prompt="$raw" ;;
    esac
    [ -n "$prompt" ] || prompt="$raw"

    t0=${EPOCHREALTIME/./}
    out="$(timeout "$STEP" bash "$0" --prompt "$prompt" --json 2>/dev/null)" && rc=0 || rc=$?
    t1=${EPOCHREALTIME/./}
    ms=$(( (t1 - t0) / 1000 ))
    total_ms=$((total_ms + ms))
    gate=ok
    [ "$rc" = 124 ] && gate=timeout
    [ "$rc" = 1 ] && gate=harness
    [ "$rc" = 2 ] && gate=escalated
    [ "$rc" = 3 ] && gate=confirm
    case "$gate" in timeout | harness) [ "$worst" = 0 ] && worst=1 ;; esac

    printf '%s' "${out:-null}" | jq -c --argjson n "$n" --arg prompt "$prompt" \
      --argjson ms "$ms" --argjson exit "$rc" --arg gate "$gate" '
      ({n: $n, prompt: $prompt, ms: $ms, exit: $exit, gate: $gate}
       + (if type == "object" and has("decision") then
            {decision, pareto, task, confidence, repaired, fallback, reason, context}
          else {decision: "error"} end))
      | with_entries(select(.value != null))'
  done
  jq -cn --argjson steps "$n" --argjson total_ms "$total_ms" --argjson failed "$worst" \
    '{steps: $steps, total_ms: $total_ms, failed: ($failed == 1)}' >&2
  exit "$worst"
fi

if [ -z "$PROMPT" ]; then
  echo "toolcall: --prompt is required" >&2
  exit 1
fi

# --- reducible: the half of the Pareto rule that needs no model ----------------
# A request asking two independent things is DECOMPOSABLE, and that is the
# reasoning agent's job: one cheap call would answer half of it and leave the
# other half silently missing, which is worse than a refusal. Split on clause
# joins, not on words — `skills tagged nix and sops` is one ask with two values,
# and turning that into two tag calls is still correct, so the rule errs toward
# splitting. Counted here, before the engine, because it is a syntactic property.
PARTS="$(awk '
  { gsub(/[?;]/, "?\n"); print }
' <<<"$PROMPT" | awk 'NF' | awk '
  BEGIN { n = 1 }
  { if (NR > 1) n++; }
  END { print n }
')"
COMPOUND=0
# `grep -o` exits 1 with no match, and under `set -e` that killed every non-compound
# prompt (measured: the dispatcher exited silently on "what touches fern").
declared_asks="$(tr 'A-Z' 'a-z' <<<"$PROMPT" | grep -oE '(^|[?;.] |, )and | and | then | also ' | wc -l || true)"
if [ "$PARTS" -gt 1 ] || [ "${declared_asks:-0}" -gt 0 ]; then COMPOUND=1; fi

# --- non-reducible AND large: a judgement or an operation, not a lookup --------
# The quadrant needle3 must never enter. A causal or advisory question has no
# small deterministic answer, and the graph will happily return SOMETHING for it
# (`why is the fleet slow` resolved to a tag bundle through the word "fleet" —
# measured 2026-11-02), which is worse than a refusal because it looks answered.
# Procedural "how do I deploy X" is the same quadrant: it is an operation, and the
# reasoning agent budgets it.
JUDGEMENT_RE='(^| )(why|should|explain|design|plan|compare|decide|better|improve|optimi[sz]e|fix|debug|recommend|refactor|review|how do i|how to)( |$)'
LARGE=0
if tr 'A-Z' 'a-z' <<<"$PROMPT" | grep -qE "$JUDGEMENT_RE"; then LARGE=1; fi

# The engine's tool set comes from the block above (`edge-check` and the login unit
# both use that path, so there is one derivation of the surface, not three).

emit() { jq -n -c "$@" <<<"null"; }
# TOON for an agent, JSON for a program. `toon -e` encodes; a missing encoder must
# not fail the call, so JSON is the fallback rather than an error.
show() {
  if [ "$MODE" = json ]; then
    printf '%s\n' "$1"
  elif command -v toon >/dev/null 2>&1; then
    printf '%s' "$1" | toon -e
  else
    printf '%s\n' "$1"
  fi
}

# Pareto, quadrant 2: reducible. Refused BEFORE the engine, so a compound request
# costs nothing and cannot be half-answered by whichever tool the model liked.
if [ "$COMPOUND" = 1 ]; then
  if [ "$MODE" = json ]; then
    show "$(emit --arg p "$PROMPT" --argjson n "$PARTS" '
      {decision: "refuse", pareto: "decompose", fallback: "reasoning",
       reason: "the request asks more than one thing; split it and send each part here",
       parts: $n}')"
  else
    printf 'decision: refuse\npareto: decompose\nfallback: reasoning\nreason: the request asks more than one thing; split it and send each part here\n'
  fi
  exit 2
fi

# Pareto, quadrant 3: large and non-reducible. Refused before the engine too: the
# cheapest answer to "why is X slow" is not a graph query, and paying 850 ms to
# manufacture a plausible-looking bundle is the worst of both.
if [ "$LARGE" = 1 ]; then
  if [ "$MODE" = json ]; then
    show "$(emit --arg p "$PROMPT" '
      {decision: "refuse", pareto: "reason", fallback: "reasoning",
       reason: "a judgement or an operation, not a lookup: do it, or split it into lookups"}')"
  else
    printf 'decision: refuse\npareto: reason\nfallback: reasoning\nreason: a judgement or an operation, not a lookup: do it, or split it into lookups\n'
  fi
  exit 2
fi


# --- one tool, and the graph owns the type (TOOLCALL_SINGLE=1) --------------
# The six-tool surface asks a 29M caller to choose among six schemas, and the
# schemas are what prefill costs. Measured 2026-11-02: one tool 246 ms, six tools
# 750-900 ms. The same runs had the ENTITY right every time and the TYPE wrong
# often (`tag(fern)` for a host, `doc(qmd)` for a skill) — a choice the graph then
# discards and corrects. So this mode asks only for the entity and synthesizes a
# `host` call, which is exactly the input the type-repair block below is built to
# fix; it is the same dispatcher, with the unreliable half of the question removed.
# Off by default: a measurement instrument until the battery says otherwise.
SINGLE="${TOOLCALL_SINGLE:-0}"
if [ "$SINGLE" = 1 ]; then
  SINGLE_FILE="$SURFACE_CACHE_DIR/engine-tools-single.json"
  if [ ! -s "$SINGLE_FILE" ]; then
    jq -n '[{name: "graph_lookup",
             description: "Look up one entity in the fleet knowledge graph: a host, a skill, a tag or a document",
             parameters: {type: "object",
                          properties: {entity: {type: "string", description: "the entity name, e.g. fern"}},
                          required: ["entity"]}}]' >"$SINGLE_FILE"
  fi
  TOOLS_FILE="$SINGLE_FILE"
  # A separate port: the sidecar restarts when the surface it booted with changes,
  # and ping-ponging modes must not pay a weights load per call.
  export EDGE_PORT="${EDGE_PORT:-18931}"
fi

# The resident caller is an OPTIMISATION, never a dependency: anything it cannot
# do falls through to a one-shot engine call, so a dead sidecar costs ~600 ms and
# never a wrong answer. Measured 2026-11-02 on this host: one-shot 1.37-1.43 s,
# resident 0.75-0.90 s for the same picks and the same confidences.
EDGE_SIDE="$REPO/scripts/task/edge-sidecar.sh"
OUT=""
if [ -z "${TOOLCALL_ONE_SHOT:-}" ] && [ -x "$EDGE_SIDE" ]; then
  OUT="$("$EDGE_SIDE" ask "$TOOLS_FILE" "$PROMPT" 2>/dev/null || true)"
  # A body without a function_calls array is not an answer, whatever the status.
  jq -e '.function_calls | type == "array"' <<<"${OUT:-null}" >/dev/null 2>&1 || OUT=""
fi

if [ -z "$OUT" ]; then
  ENGINE="${NEEDLE_ENGINE:-$(ls -d /nix/store/*-needle-3/bin/needle 2>/dev/null | tail -1)}"
  WEIGHTS="${NEEDLE_WEIGHTS:-$(ls /nix/store/*-needle3.cact 2>/dev/null | tail -1)}"
  if [ -z "$ENGINE" ] || [ ! -x "$ENGINE" ] || [ -z "$WEIGHTS" ]; then
    echo "toolcall: needle engine or weights not found (NEEDLE_ENGINE / NEEDLE_WEIGHTS)" >&2
    exit 1
  fi
  # Telemetry is on by default in the shipped binary; an edge caller on a private
  # fleet does not phone home.
  OUT="$(NEEDLE_TELEMETRY=0 DO_NOT_TRACK=1 "$ENGINE" --model "$WEIGHTS" \
    --tools "$TOOLS_FILE" --prompt "$PROMPT" 2>/dev/null)" || {
    echo "toolcall: the engine exited non-zero" >&2
    exit 1
  }
fi


# The single-tool answer becomes a candidate `host` call, so everything below —
# validation, type repair, prefetch, the router fallback — runs unchanged. An
# entity the engine could not extract becomes NO call rather than a guess, which
# is what sends it to the router.
if [ "$SINGLE" = 1 ]; then
  ENTITY="$(jq -r '(.function_calls[0].arguments.entity // .function_calls[0].arguments.ENTITY // "") | tostring' <<<"${OUT:-{\}}" 2>/dev/null || true)"
  if [ -n "${ENTITY:-}" ]; then
    OUT="$(jq -c --arg e "$ENTITY" '.function_calls = [{name: "ops_kg_host", arguments: {host: $e}}]' <<<"$OUT")"
  else
    OUT="$(jq -c '.function_calls = []' <<<"${OUT:-{\}}" 2>/dev/null || echo '{"function_calls":[]}')"
  fi
fi

CONF="$(jq -r '.confidence // 0' <<<"$OUT")"
# Validation before confidence: an invented tool is a refusal whatever the score
# says, and an ungrounded call is the engine telling us its own argument is not in
# the input.
UNKNOWN="$(jq -c --argjson tools "$TOOLS" '
  [.function_calls[]? | .name] | map(select(. as $n | ($tools | map(.name) | index($n)) == null))' <<<"$OUT")"
UNGROUNDED="$(jq -c '.validation.ungrounded // []' <<<"$OUT")"
NCALLS="$(jq '.function_calls | length' <<<"$OUT")"

# --- the cascade: model call -> graph router -> reasoning model ---------------
# Each step is cheaper than the next and only the last costs tokens per attempt,
# so the expensive one is what a decline hands the turn to. The router is
# `ops:ask` when it is on the surface: it either names a node and prints its
# bundle, or declines with intent=UNKNOWN and a non-zero exit (kg-ask.sh).
MULTI=0
if [ "$NCALLS" -gt 1 ]; then MULTI=1; fi

CALL=""
TASK=""
REPAIR=null
ARGV=()
CMD=""
USABLE=1
REASON=""

[ "$NCALLS" -ge 1 ] || {
  USABLE=0
  REASON="no call"
}
if [ "$USABLE" = 1 ] && [ "$UNKNOWN" != "[]" ]; then
  USABLE=0
  REASON="unknown tool: $(jq -r 'join(",")' <<<"$UNKNOWN")"
fi
if [ "$USABLE" = 1 ] && [ "$UNGROUNDED" != "[]" ]; then
  USABLE=0
  REASON="ungrounded argument: $(jq -r 'join(",")' <<<"$UNGROUNDED")"
fi

if [ "$USABLE" = 1 ]; then
  CALL="$(jq -c '.function_calls[0]' <<<"$OUT")"
  TASK="$(jq -r --argjson t "$TOOLS" --arg n "$(jq -r '.function_calls[0].name' <<<"$OUT")" \
    '$t[] | select(.name == $n) | .task' <<<"null")"
  # A call with no `arguments` object is real engine output (measured 2026-11-02),
  # so it is an unusable call, not a reason to crash the dispatcher.
  if [ "$(jq -r '(.arguments // null) | type' <<<"$CALL")" != "object" ]; then
    USABLE=0
    REASON="the call carried no arguments"
  fi
fi

if [ "$USABLE" = 1 ]; then
  # An argv array, not a shell string: a value with a space in it (`qmd skill`)
  # was split into a separate task-name argument, so `task` printed its whole
  # task list instead of the answer and the prefetch returned the menu.
  mapfile -t ARGV < <(jq -r '.arguments | to_entries[] | "\(.key | ascii_upcase)=\(.value)"' <<<"$CALL")

  # --- the graph repairs the type the model guessed -------------------------
  # Measured 2026-11-02 on the six-tool surface: needle3 extracts the ENTITY well
  # (`fern`, `qmd`, `eisen`, `nix`) and mislabels its TYPE often (`tag(fern)` for a
  # host, `doc(qmd)` for a skill). A prefetch must not inherit that — the wrong
  # pattern returns nothing — so the type is not trusted. When `<param>:<value>`
  # is not a node but another type carries the name, the call is rewritten to
  # that type's own lookup. The model keeps the job it is good at, naming the
  # thing; the graph keeps the one it can prove. Repairs are reported, never
  # silent, and TOOLCALL_NO_REPAIR=1 turns the whole thing off so the raw pick
  # stays measurable.
  PARAM="$(jq -r '.arguments | to_entries[0].key // ""' <<<"$CALL")"
  VALUE="$(jq -r '.arguments | to_entries[0].value // ""' <<<"$CALL")"
  case "$PARAM" in
  host | skill | tag | doc) ;;
  *) VALUE="" ;;
  esac
  # `host:fern` arrives as `fern`; a caller that prefixes named the same thing.
  VALUE="${VALUE#"$PARAM:"}"
  if [ -n "$VALUE" ] && [ -z "${TOOLCALL_NO_REPAIR:-}" ]; then
    GRAPH_FILE="$(kg_graph_path 2>/dev/null || true)"
    if [ -n "${GRAPH_FILE:-}" ] && [ -f "$GRAPH_FILE" ]; then
      # One jq pass to a newline list, then `grep -Fx`: the first version called
      # `jq -e` per candidate, which re-parsed the whole graph JSON (1 MB) two or
      # three times and cost more than the lookup it was repairing.
      NODE_IDS="$(jq -r '.nodes[].id' "$GRAPH_FILE" 2>/dev/null || true)"
      node_exists() { grep -Fxq -- "$1" <<<"$NODE_IDS"; }
      # A caller also glues the type onto the name (`qmd skill`), so the graph
      # decides where the name ends: longest candidate first, its own type first.
      mapfile -t WORDS < <(tr -s ' ' '\n' <<<"$VALUE")
      CANDIDATES=()
      for ((i = ${#WORDS[@]}; i >= 1; i--)); do
        CANDIDATES+=("$(IFS=' '; printf '%s' "${WORDS[*]:0:i}")")
      done
      for cand in "${CANDIDATES[@]}"; do
        # Graph ids are lowercase by construction, and the model capitalises an
        # argument that starts the prompt sentence (`Sops` for tag:sops).
        cand="${cand,,}"
        if node_exists "$PARAM:$cand"; then
          VALUE="$cand"
          break
        fi
        repaired=""
        for t in host skill tag doc; do
          [ "$t" = "$PARAM" ] && continue
          node_exists "$t:$cand" || continue
          jq -e --arg t "ops:kg:$t" 'map(select(.task == $t)) | length == 1' <<<"$TOOLS" >/dev/null || continue
          repaired="$t"
          break
        done
        if [ -n "$repaired" ]; then
          REPAIR="$(jq -c -n --arg from "$PARAM" --arg to "$repaired" --arg v "$cand" \
            '{from: $from, to: $to, node: ($to + ":" + $v)}')"
          TASK="ops:kg:$repaired"
          PARAM="$repaired"
          VALUE="$cand"
          CALL="$(jq -c --arg k "$repaired" --arg v "$cand" '{name: ("ops_kg_" + $k), arguments: {($k): $v}}' <<<"$CALL")"
          break
        fi
      done
      if [ "$USABLE" = 1 ] && [ -n "$VALUE" ]; then
        ARGV=("$(tr '[:lower:]' '[:upper:]' <<<"$PARAM")=$VALUE")
      fi
    fi
  fi
fi

# task echoes the command it runs unless silenced; that header is not context.
run_task() { (cd "$REPO" && task -s "$TASK" "${ARGV[@]}") 2>&1; }
cmdline() {
  if [ "${#ARGV[@]}" -eq 0 ]; then
    printf 'task -s %s\n' "$TASK"
  else
    printf 'task -s %s%s\n' "$TASK" "$(printf ' %q' "${ARGV[@]}")"
  fi
}
CMD="$(cmdline)"

# Class first, confidence second: read-only tools prefetch whatever the score
# says; everything else keeps the act gate.
READ_ONLY_RE="${TOOLCALL_READ_ONLY:-^(ops:kg:|ops:ask$)}"
IS_READ=0
if [[ "$TASK" =~ $READ_ONLY_RE ]]; then IS_READ=1; fi

router_available() {
  jq -e --arg t "ops:ask" 'map(select(.task == $t)) | length == 1' <<<"$TOOLS" >/dev/null
}

# The router is a task like any other: it prints the bundle, or declines with a
# non-zero exit. Both are answers; neither costs a reasoning round.
router_prefetch() {
  ROUTE_RC=0
  ROUTE_OUT="$( (cd "$REPO" && task -s ops:ask "Q=$PROMPT") 2>&1 )" || ROUTE_RC=$?
}

show_prefetch() {
  if [ "$MODE" = json ]; then
    show "$(emit --arg task "$TASK" --arg cmd "$CMD" --argjson conf "$CONF" --argjson call "${CALL:-null}" \
      --arg out "$CONTEXT" --argjson repair "$REPAIR" --arg fallback "$FALLBACK" --argjson multi "$MULTI" \
      '{decision: "prefetch", pareto: "needle3", read_only: true, task: $task, command: $cmd, confidence: $conf,
        call: $call, repaired: $repair,
        fallback: (if $fallback == "null" then null else $fallback end),
        ambiguous: ($multi == 1), context: $out}')"
    return
  fi
  # Header as TOON, context verbatim: re-encoding a listing as an array of quoted
  # strings is how the same bytes cost three times as many tokens.
  printf 'prefetch: %s\npareto: needle3\nconfidence: %s\n' "${TASK:-ops:ask}" "$CONF"
  [ -n "$CMD" ] && printf 'query: %s\n' "$CMD"
  if [ "$REPAIR" != null ]; then
    printf 'repaired: %s -> %s (the graph owns the type)\n' \
      "$(jq -r '.from' <<<"$REPAIR")" "$(jq -r '.node' <<<"$REPAIR")"
  fi
  if [ "$FALLBACK" != null ]; then
    printf 'fallback: %s (nothing above named a node the graph knows)\n' "$FALLBACK"
  fi
  printf 'context:\n%s\n' "$CONTEXT"
}

refuse() {
  show "$(emit --argjson conf "$CONF" --argjson out "$OUT" --arg reason "$1" '
    {decision: "refuse", pareto: "reason", fallback: "reasoning", confidence: $conf, reason: $reason,
     reasoning: $out.reasoning, calls: ($out.function_calls // [])}')"
  exit 2
}

# kg-ask exits 0 on UNKNOWN and prints its menu, so a decline is in the BODY.
# A prefetch that returns a generic top-N list is noise an agent pays tokens for;
# a decline is an instruction to reason. Same test for the model's own `ops:ask`
# call and for the router fallback — the body is the contract either way.
declined() { grep -qE '^intent[[:space:]]*: UNKNOWN' <<<"$1"; }

# 1. the call path: usable AND read-only, or the router answers for it.
if [ "$USABLE" != 1 ] || [ "$IS_READ" = 1 ]; then
  FALLBACK=null
  CONTEXT=""
  if [ "$USABLE" = 1 ] && [ "$DRY_RUN" = 1 ]; then
    show_prefetch
    exit 0
  fi
  if [ "$USABLE" = 1 ] && CONTEXT="$(run_task)" && ! declined "$CONTEXT"; then
    show_prefetch
    exit 0
  fi
  # The call failed or declined. Ask the graph's own router on the FULL prompt —
  # the model's argument is often a truncated version of it (`ocean` for a
  # sentence), and the router is deterministic and cached.
  if router_available; then
    router_prefetch
    if [ "$ROUTE_RC" -eq 0 ] && ! declined "$ROUTE_OUT"; then
      CONTEXT="$ROUTE_OUT"
      FALLBACK=ops:ask
      TASK="ops:ask"
      ARGV=("Q=$PROMPT")
      CMD="$(cmdline)"
      show_prefetch
      exit 0
    fi
    DECLINE_REASON="${REASON:-the graph named no node}"
    if [ "$MODE" = json ]; then
      show "$(emit --argjson conf "$CONF" --arg reason "$DECLINE_REASON" --arg out "$ROUTE_OUT" '
        {decision: "refuse", pareto: "reason", fallback: "reasoning", confidence: $conf, reason: $reason, router: $out}')"
    else
      # The router's body verbatim (columns trimmed) rather than a JSON-quoted
      # string: the decline is evidence, and quoting it costs tokens for nothing.
      printf 'decision: refuse\nfallback: reasoning\nconfidence: %s\nreason: %s\nrouter:\n%s\n' \
        "$CONF" "$DECLINE_REASON" "$(sed -e 's/[[:space:]]*$//' <<<"$ROUTE_OUT")"
    fi
    exit 2
  fi
  refuse "$REASON"
fi

# 2. a mutating call: exactly one, unambiguous, and above a threshold.
if [ "$MULTI" = 1 ]; then
  refuse "no single call"
fi

if awk -v c="$CONF" -v a="$ACT" 'BEGIN{exit !(c >= a)}'; then
  if [ "$DRY_RUN" = 1 ]; then
    show "$(emit --arg cmd "$CMD" --argjson conf "$CONF" --argjson call "$CALL" \
      '{decision: "act", pareto: "needle3", dry_run: true, command: $cmd, confidence: $conf, call: $call}')"
    exit 0
  fi
  RESULT="$(cd "$REPO" && task -s "$TASK" "${ARGV[@]}" 2>&1)" || true
  show "$(emit --arg cmd "$CMD" --argjson conf "$CONF" --argjson call "$CALL" --arg out "$RESULT" \
    '{decision: "act", pareto: "needle3", dry_run: false, command: $cmd, confidence: $conf, call: $call, output: $out}')"
  exit 0
fi

if awk -v c="$CONF" -v b="$CONFIRM" 'BEGIN{exit !(c >= b)}'; then
  show "$(emit --arg cmd "$CMD" --argjson conf "$CONF" --argjson call "$CALL" \
    '{decision: "confirm", pareto: "needle3", command: $cmd, confidence: $conf, call: $call}')"
  exit 3
fi

show "$(emit --argjson conf "$CONF" --argjson out "$OUT" '
  {decision: "refuse", pareto: "reason", fallback: "reasoning", confidence: $conf,
   reason: "below the confirm threshold", reasoning: $out.reasoning}')"
exit 2
