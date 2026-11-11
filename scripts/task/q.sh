#!/usr/bin/env bash
# q.sh — the selector's executor: validate a query object, run it over a compiled
# registry, answer in TOON with pointers, or refuse.
#
# Design: docs/selector-daemon-predesign.md §3–§4. Stages 2–4 of that pipeline;
# stage 0/1 (shortlist, question -> query object) is the model's job and is NOT
# here. At M0 the shortlist is folded into the one jq pass: a term that names
# nothing returns zero rows, which is exit 3 — so refusal is cheap by being the
# same pass, and `checks:selector` prints what it actually costs.
#
#   q.sh 'registry: notes'                     a TOON query object (stdin: -)
#   q.sh '{"registry":"notes","filter":{"status":"OPEN"}}'      JSON also accepted
#   q.sh --registry notes --status OPEN --touches sops
#   q.sh --show notes.daemon-earns-it-by-compression            verify one pointer
#   q.sh --question 'which notes are blocked'                   stage 1: model -> object
#   q.sh --self-test                                            the edge cases, offline
#   q.sh --schema notes | --data notes | --searchable notes      the generator's inputs
#
# Q_DATA=<file> answers from that payload instead of evaluating — the hook the
# self-test uses, so the offline cases never touch nix. Q_NO_SIDECAR=1 skips the
# resident stage 1 (scripts/task/selector-sidecar.sh) and runs the interpreter.
#
# Query object: registry, filter (field: value), fields, limit. `filter.touches`
# is the operator, not a field: it searches only the fields a registry NAMES a
# thing in (refs, title, desc, software…), never a note body — a `touches` claim
# has to be one the answer can point at, and a body match is not. It is stripped
# from the filter list before the schema check, because there is no column called
# `touches`; reading it as one made the object unable to say "notes that mention
# mqtt" at all, which is the one query shape a keyword search is for.
#
# Registry -> compiled truth (never a second copy):
#   inventory  nix eval .#inventory.hosts            id = host name
#   notes      nix eval .#agentsNotes.notes          id = note id
#   graph      nix eval .#knowledgeGraph.graph       id = node id; in/out degree
#   tasks      taskfile_graph.py by-name             id = task name; build = body
#   ledger     /var/lib/fleet-sentinel/ledger.jsonl  id = unit (flattened jobs)
# The three evals are cached per working-tree content (rev + sha1(git diff HEAD));
# the graph goes through lib/kg-graph.sh, the same cache kg-query and the sidecar
# use, so no surface can answer from a different graph.
#
# Field kinds decide the comparison: enum is exact (id, status, kind, type,
# result, state), num is `>=` (in/out/lines/degree), bool is true/false, anything
# else is a case-insensitive SUBSTRING over the field flattened to text (an object
# or array is joined, so HARDWARE=thinkpad works). id is exact on purpose: a
# substring match on a NAME is how `--name frieren` answered frieren-canary too.
#
# OUTPUT IS TOON ([[flake/policies.nix#agent-boundary-is-toon]]): the agent reads
# a document it can decode, not a line of prose, and the machine (jq -> toon)
# owns the quoting and the `[n]`. The answer is capped at 80 tokens (320 B) by
# dropping rows and saying `withheld: N`; values are clipped at 64 chars, which
# is what the pointer is for. `--json` exists for programs and carries the full
# row set plus `bytes`, the byte length of the TOON an agent would read — the
# number checks:selector computes S from.
#
# Exit: 0 = answered; 1 = registry unavailable (eval failed, no ledger, no toon);
#       2 = the query is invalid (unknown registry/field/value shape, unknown
#       --show id); 3 = refused — a valid question with no answer, which is the
#       cheap outcome this exists to make cheap. 2 and 3 are both refusals to a
#       caller; 2 is the caller's bug, 3 is the data's.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig"
REG=""
QUERY=""
QUESTION=""
JSON_MODE=0
SHOW=""
FIELDS=""
LIMIT=""
TOUCHES=""
FILTERS=()

usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"; }
say() { printf 'q: %s\n' "$*" >&2; }

now_ms() {
  if [ -n "${EPOCHREALTIME:-}" ]; then
    local t="${EPOCHREALTIME/./}"
    printf '%s' "$((t / 1000))"
  else
    date +%s%3N
  fi
}
T0="$(now_ms)"
elapsed() { printf '%s' "$(($(now_ms) - T0))"; }

need_toon() {
  command -v toon >/dev/null 2>&1 && return 0
  say "toon is not on PATH; the answer would have to be hand-formatted, which is the failure this surface exists to prevent."
  say "nix run github:numtide/llm-agents.nix#toon -- --help"
  exit 1
}

# One refusal shape for every stage: the agent decodes it, it never parses prose.
refuse() {
  local code="$1" reason="$2"
  shift 2
  if [ "$JSON_MODE" = 1 ]; then
    jq -nc --arg r "$reason" --arg d "$*" --argjson ms "$(elapsed)" \
      '{refused: true, reason: $r, detail: $d, elapsed_ms: $ms}'
  else
    jq -nc --arg r "$reason" --arg d "$*" \
      '{refused: true, reason: $r, detail: $d}' | toon -e >&2
  fi
  exit "$code"
}

# --- registry schema ---------------------------------------------------------
# The ONLY place a field's existence and kind are declared. Stage 2 checks
# against this table, and the jq below only ever sees names that passed it — the
# reason a field the registry does not have cannot reach execution.
schema() {
  case "$1" in
    inventory)
      printf '%s\n' \
        "id:enum" "hostname:text" "role:text" "kind:enum" "arch:text" \
        "status:enum" "status_detail:text" "category:text" "persona:text" \
        "managed:bool" "is_nix:bool" "system_type:text" "desktop_environment:text" \
        "builder:text" "ci:bool" "flake:bool" "network:text" "hardware:text" \
        "software:text" "users:text" "notes:text"
      ;;
    notes)
      printf '%s\n' \
        "id:enum" "kind:enum" "status:enum" "priority:text" "date:text" \
        "title:text" "summary:text" "body:text" "leaf:bool" "lines:num" \
        "refs.modules:list" "refs.tasks:list" "refs.docs:list" "refs.hosts:list" \
        "from:list" "supersedes:list" "replacedBy:list"
      ;;
    graph)
      printf '%s\n' \
        "id:enum" "type:enum" "label:text" "kind:text" "status:text" \
        "in:num" "out:num"
      ;;
    tasks)
      printf '%s\n' \
        "id:enum" "desc:text" "summary:text" "shard:text" "build:bool" \
        "retired:bool" "wildcards:num" "refs:list" "aliases:list"
      ;;
    ledger)
      printf '%s\n' \
        "id:enum" "ts:text" "host:text" "unit:text" "result:text" \
        "state:text" "generation_age_h:num" "disk_root:num" "psi_io:num"
      ;;
    *) return 1 ;;
  esac
}

searchable() {
  case "$1" in
    inventory) printf '%s\n' hostname role category status status_detail kind notes software hardware persona users ;;
    notes) printf '%s\n' id title summary refs.modules refs.tasks refs.docs refs.hosts ;;
    graph) printf '%s\n' id label type kind status ;;
    tasks) printf '%s\n' id desc summary shard refs aliases ;;
    ledger) printf '%s\n' unit host state result ;;
  esac
}

default_fields() {
  case "$1" in
    inventory | notes) printf 'status' ;;
    ledger) printf 'result' ;;
    graph) printf 'type' ;;
    tasks) printf 'shard' ;;
  esac
}

# --- self-test ---------------------------------------------------------------
# The edge cases a reader has to be able to trust without the compiled registries:
# the three refusal classes, the exit codes that distinguish them, and the 80-token
# budget actually cutting rows. Fixtures are synthesized with jq and fed through
# Q_DATA, so this runs offline and cannot pass because the data happened to fit.
self_test() {
  local tmp pass=0 fail=0 case out rc bytes text with rows one
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  jq -n '
    def long: "a deliberately long title that exists only to force the render budget to drop rows " + ("x" * 40);
    def note($id; $st; $title): {($id): {
      id: $id, kind: "open", status: $st, priority: "P2", date: "2026-11-02",
      title: $title, summary: "fixture row", body: "", leaf: false, lines: 3,
      from: [], supersedes: [], replacedBy: [],
      refs: {modules: [], tasks: [], docs: [], hosts: []}}};
    reduce ("short-open", "long-1", "long-2", "long-3", "long-4", "long-5") as $id
      ({}; . + (if $id == "short-open" then note($id; "OPEN"; "short title") else note($id; "OPEN"; long) end))
    | .["short-open"].refs.docs = ["docs/selector-daemon-predesign.md"]
  ' >"$tmp/notes.json"

  ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
  bad() {
    fail=$((fail + 1))
    printf '  FAIL %s\n' "$1"
  }

  # expect <exit> <reason|-> <label> -- <args>
  expect() {
    local want_rc="$1" want_reason="$2" label="$3" got
    shift 3
    [ "${1:-}" = "--" ] && shift
    rc=0
    out="$(Q_DATA="$tmp/notes.json" bash "$0" "$@" --json 2>/dev/null)" || rc=$?
    if [ "$rc" != "$want_rc" ]; then
      bad "$label: exit $rc, wanted $want_rc"
      return
    fi
    if [ "$want_reason" != "-" ]; then
      got="$(jq -r '.reason // ""' <<<"$out" 2>/dev/null)"
      if [ "$got" != "$want_reason" ]; then
        bad "$label: reason '$got', wanted '$want_reason'"
        return
      fi
    fi
    ok "$label"
  }

  printf 'q self-test (offline fixtures)\n'

  # answered: the positive control every refusal is measured against
  expect 0 - "answered" -- --registry notes --limit 6 --fields title

  # refused as INVALID (exit 2): the query cannot be expressed
  expect 2 schema "unknown registry" -- --registry nope
  expect 2 schema "unknown filter field" -- --registry notes --temperature 95
  expect 2 schema "unknown projected field" -- --registry notes --fields temperature
  expect 2 schema "limit below range" -- --registry notes --limit 0
  expect 2 schema "limit not a number" -- --registry notes --limit x
  expect 2 schema "unknown --show id" -- --show notes.missing
  expect 2 schema "malformed query document" -- 'registry: [not: a document'
  expect 2 schema "query-object limit above range" -- '{"registry":"notes","limit":99}'

  # refused as EMPTY (exit 3): a valid question the data does not answer
  expect 3 empty "no matching rows" -- --registry notes --touches zzzz

  # touches inside a query object is an OPERATOR, not a column: it was read as a
  # field and refused with "no field 'touches'", which made the keyword question
  # unexpressible from an object while it worked from the CLI.
  expect 0 - "touches in a query object" -- '{"registry":"notes","filter":{"touches":"short"},"limit":1}'
  expect 3 empty "touches in a query object that matches nothing" -- '{"registry":"notes","filter":{"touches":"zzzz"},"limit":1}'

  # A multi-word term is an AND over its words: speech names
  # `docs/selector-daemon-predesign.md` as "the selector predesign", which one
  # literal substring could not see, so the question refused as empty.
  out="$(Q_DATA="$tmp/notes.json" bash "$0" --registry notes --touches "selector predesign" --json 2>/dev/null)" || true
  got="$(jq -r '[.rows[].id] | join("|")' <<<"$out" 2>/dev/null)"
  if [ "$got" = "short-open" ]; then
    ok "multi-word touches finds a doc path by its slug"
  else
    bad "multi-word touches: rows '$got', wanted short-open"
  fi

  # the 80-token budget: six wide rows must not fit, and the drop must be declared
  rc=0
  text="$(Q_DATA="$tmp/notes.json" bash "$0" --registry notes --limit 6 --fields title 2>/dev/null)" || rc=$?
  bytes="$(printf '%s' "$text" | wc -c)"
  if [ "$rc" = 0 ] && [ "$bytes" -le 320 ]; then
    ok "render is $bytes B, budget 320"
  else
    bad "render exit $rc, $bytes B (budget 320)"
  fi
  if printf '%s\n' "$text" | toon -d >/dev/null 2>&1; then
    ok "render strict-decodes as TOON"
  else
    bad "render does not decode as TOON"
  fi
  with="$(printf '%s\n' "$text" | toon -d 2>/dev/null | jq -r '.withheld // 0')"
  rows="$(printf '%s\n' "$text" | toon -d 2>/dev/null | jq -r '.rows | length')"
  if [ "$with" -gt 0 ] && [ $((with + rows)) = 6 ]; then
    ok "dropped rows are declared (rows $rows + withheld $with = 6)"
  else
    bad "withheld accounting: rows $rows + withheld $with, wanted 6 total"
  fi

  one="$(Q_DATA="$tmp/notes.json" bash "$0" --registry notes --limit 1 --fields title 2>/dev/null)"
  if printf '%s\n' "$one" | toon -d 2>/dev/null | jq -e 'has("withheld") | not' >/dev/null; then
    ok "a narrow answer carries no withheld key"
  else
    bad "a narrow answer invented a withheld key"
  fi

  printf '%s\n' "q self-test: $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
}

# --- arg parsing -------------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --self-test)
      self_test
      exit $?
      ;;
    --schema)
      schema "${2:-}" || {
        echo "q: unknown registry '${2:-}' (inventory|notes|graph|tasks|ledger)" >&2
        exit 2
      }
      exit 0
      ;;
    # The generator's third input: the fields `touches` actually searches, so a
    # training pair and the executor cannot disagree about what a mention is.
    --searchable)
      searchable "${2:-}" || {
        echo "q: unknown registry '${2:-}' (inventory|notes|graph|tasks|ledger)" >&2
        exit 2
      }
      exit 0
      ;;
    --data) DUMP_DATA="${2:-}"; shift 2 ;;
    --question) QUESTION="${2:-}"; shift 2 ;;
    --question=*) QUESTION="${1#*=}"; shift ;;
    --schema=*) schema "${1#*=}" || {
      echo "q: unknown registry '${1#*=}'" >&2
      exit 2
    }
    exit 0
    ;;
    --data=*) DUMP_DATA="${1#*=}"; shift ;;
    -) QUERY="$(cat)"; shift ;;
    --json) JSON_MODE=1; shift ;;
    --show) SHOW="${2:-}"; shift 2 ;;
    --show=*) SHOW="${1#*=}"; shift ;;
    --registry) REG="${2:-}"; shift 2 ;;
    --registry=*) REG="${1#*=}"; shift ;;
    --fields) FIELDS="${2:-}"; shift 2 ;;
    --fields=*) FIELDS="${1#*=}"; shift ;;
    --limit) LIMIT="${2:-}"; shift 2 ;;
    --limit=*) LIMIT="${1#*=}"; shift ;;
    --touches | --q) TOUCHES="${2:-}"; shift 2 ;;
    --touches=* | --q=*) TOUCHES="${1#*=}"; shift ;;
    --name) FILTERS+=("id=${2:-}"); shift 2 ;;
    --name=*) FILTERS+=("id=${1#*=}"); shift ;;
    --*=*) FILTERS+=("${1#--}"); shift ;;
    --*)
      key="${1#--}"
      if [ -n "${2:-}" ] && [ "${2#-}" = "$2" ]; then
        FILTERS+=("$key=$2")
        shift 2
      else
        refuse 2 schema "option --$key needs a value (or --$key=VALUE); a registry field is a filter, not a switch"
      fi
      ;;
    -*) refuse 2 schema "unknown option '$1' (see --help)" ;;
    *) QUERY="$1"; shift ;;
  esac
done

if [ -n "$QUESTION" ]; then
  # Stage 1: the model turns the question into the object; stages 2-4 below are
  # unchanged, so a wrong object is caught by the same schema check and the same
  # empty-result refusal as a human-written one.
  Q_MODEL="${Q_MODEL:-$CACHE/selector/selector-nb.json}"
  [ -s "$Q_MODEL" ] ||
    refuse 3 empty "no trained selector model at $Q_MODEL (task ops:q:train)"

  # The resident stage 1 (tools/selector/serve.py) answers the same JSON without
  # paying interpreter start plus a 1 MB model load on every question. It is an
  # accelerator with a fallback, never a second implementation — it imports this
  # same model.py — and a reply that is neither an object nor a refusal is treated
  # as no reply, so a half-broken daemon degrades to the interpreter instead of
  # answering garbage. Q_NO_SIDECAR=1 measures the portable path.
  stage1_via_sidecar() {
    local sock="${SELECTOR_SOCKET:-${XDG_RUNTIME_DIR:-/tmp}/selector.sock}" reply
    [ "${Q_NO_SIDECAR:-}" = 1 ] && return 1
    [ -S "$sock" ] || return 1
    reply="$(
      jq -nc --arg q "$QUESTION" '{question: $q}' |
        curl -sS -m 2 --unix-socket "$sock" -H 'Content-Type: application/json' \
          --data-binary @- http://localhost/predict 2>/dev/null
    )" || return 1
    jq -e 'type == "object" and (.refused == true or has("registry"))' >/dev/null 2>&1 <<<"$reply" || return 1
    printf '%s' "$reply"
  }

  QUERY="$(stage1_via_sidecar || true)"
  if [ -z "$QUERY" ]; then
    QUERY="$(python3 "$REPO/tools/selector/model.py" predict --model "$Q_MODEL" --question "$QUESTION" 2>/dev/null)" || QUERY=""
  fi
  [ -n "$QUERY" ] || refuse 3 empty "stage 1 produced no query object"
  if jq -e '.refused == true' >/dev/null 2>&1 <<<"$QUERY"; then
    refuse 3 empty "stage 1 $(jq -r '.detail // "declined"' <<<"$QUERY")"
  fi
fi

if [ -n "$QUERY" ]; then
  [ "$QUERY" = "-" ] && QUERY="$(cat)"
  # TOON is the agent's boundary, JSON is the tool's: accept both, decode TOON
  # with the converter rather than with a parser written here.
  if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$QUERY"; then
    need_toon
    if ! QUERY="$(printf '%s\n' "$QUERY" | toon -d 2>/dev/null)" ||
      ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$QUERY"; then
      refuse 2 schema "query is neither a JSON object nor a TOON document"
    fi
  fi
  REG="${REG:-$(jq -r '.registry // ""' <<<"$QUERY")}"
  LIMIT="${LIMIT:-$(jq -r '.limit // ""' <<<"$QUERY")}"
  TOUCHES="${TOUCHES:-$(jq -r '.filter.touches // ""' <<<"$QUERY")}"
  [ -n "$FIELDS" ] || FIELDS="$(jq -r '(.fields // []) | join(",")' <<<"$QUERY")"
  # `touches` is an operator carried inside `filter`, not a column: it was read
  # as a field, so `{"filter":{"touches":"mqtt"}}` refused with "no field
  # 'touches'" and the object could not express a keyword question.
  while IFS= read -r spec; do
    [ -n "$spec" ] || continue
    case "${spec%%=*}" in touches | q) continue ;; esac
    FILTERS+=("$spec")
  done < <(jq -r '(.filter // {}) | to_entries[] | "\(.key)=\(.value | tostring)"' <<<"$QUERY")
fi

if [ -z "$REG" ] && [ -n "$SHOW" ]; then REG="${SHOW%%.*}"; fi
[ -z "$REG" ] && [ -n "${DUMP_DATA:-}" ] && REG="$DUMP_DATA"
[ -n "$REG" ] || refuse 2 schema "no registry (inventory|notes|graph|tasks|ledger)"

declare -A KIND=()
while IFS=: read -r f k; do [ -n "$f" ] && KIND["$f"]="$k"; done < <(schema "$REG")
if [ "${#KIND[@]}" -eq 0 ]; then
  refuse 2 schema "unknown registry '$REG' (inventory|notes|graph|tasks|ledger)"
fi

LIMIT="${LIMIT:-5}"
case "$LIMIT" in '' | *[!0-9]*) refuse 2 schema "limit must be an integer (got '$LIMIT')" ;; esac
{ [ "$LIMIT" -ge 1 ] && [ "$LIMIT" -le 20 ]; } ||
  refuse 2 schema "limit must be 1..20 (got $LIMIT)"

# Stage 2: a field the registry does not have is rejected BEFORE execution.
for spec in ${FILTERS[@]+"${FILTERS[@]}"}; do
  name="${spec%%=*}"
  [ "$name" = "name" ] && name="id"
  if [ -n "${KIND[$name]:-}" ]; then continue; fi
  refuse 2 schema "no field '$name' in $REG (have: $(printf '%s\n' "${!KIND[@]}" | sort | paste -sd' '))"
done

# A projected field is the same contract as a filter: it must exist, or the answer
# would carry a column of nulls and look like a real one.
for name in $(printf '%s' "$FIELDS" | tr ',' ' '); do
  [ -n "${KIND[$name]:-}" ] || refuse 2 schema "no field '$name' to project in $REG"
done

# --- registry data -----------------------------------------------------------
# The cache key is the working tree's CONTENT, not its dirty bit: a tree that has
# not moved between calls must not re-evaluate, and a tree that HAS moved must
# never be answered from the previous one.
tree_key() {
  local rev digest
  rev="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo untracked)"
  digest="clean"
  if ! git -C "$REPO" diff HEAD --quiet -- . 2>/dev/null; then
    digest="$(git -C "$REPO" diff HEAD -- . 2>/dev/null | sha1sum | cut -c1-12)"
  fi
  printf '%s-%s' "$rev" "$digest"
}

q_eval() {
  local name="$1" attr="$2" path
  path="$CACHE/q-$name-$(tree_key).json"
  if [ ! -s "$path" ]; then
    mkdir -p "$CACHE"
    # shellcheck source=lib/iets.sh
    . "$REPO/scripts/task/lib/iets.sh"
    if ! (cd "$REPO" && iets_eval_json ".?submodules=1#$attr") >"$path.tmp" 2>/dev/null; then
      rm -f "$path.tmp"
      say "cannot evaluate .#$attr"
      return 1
    fi
    mv "$path.tmp" "$path"
    find "$CACHE" -maxdepth 1 -name "q-$name-*.json" -type f -mtime +7 -delete 2>/dev/null || true
  fi
  printf '%s' "$path"
}

# The graph is resolved by the ONE resolver the kg:* surface already uses, so the
# sidecar, `ops:kg:*` and this query cannot answer from three different graphs.
. "$REPO/scripts/task/lib/kg-graph.sh"

# The task plane's registry: one compile of the shards (yq, by way of
# scripts/task/lib/taskfile_graph.py), reshaped into the `parsed` list the jq
# program below already reads. Keyed like every other registry, on the tree.
tasks_graph() {
  local path="$CACHE/q-tasks-$(tree_key).json"
  if [ ! -s "$path" ]; then
    mkdir -p "$CACHE"
    if ! python3 "$REPO/scripts/task/lib/taskfile_graph.py" by-name 2>/dev/null \
      | jq '{parsed: (to_entries | map(.value))}' >"$path.tmp"; then
      rm -f "$path.tmp"
      say "cannot compile the task graph"
      return 1
    fi
    mv "$path.tmp" "$path"
    find "$CACHE" -maxdepth 1 -name 'q-tasks-*.json' -type f -mtime +7 -delete 2>/dev/null || true
  fi
  printf '%s' "$path"
}

ledger_file() {
  local f="${Q_LEDGER:-/var/lib/fleet-sentinel/ledger.jsonl}"
  [ -r "$f" ] || {
    say "no sentinel ledger at $f (fleet-sentinel not enabled here?)"
    return 1
  }
  tail -n "${Q_LEDGER_LINES:-200}" "$f"
}

data_for() {
  if [ -n "${Q_DATA:-}" ]; then
    printf '%s' "$Q_DATA"
    return 0
  fi
  case "$1" in
    inventory) q_eval inventory inventory.hosts ;;
    notes) q_eval notes agentsNotes.notes ;;
    tasks) tasks_graph ;;
    graph) kg_graph_path ;;
    ledger)
      # The ledger is live JSONL, not a compiled artifact: flatten it into the
      # same one-file shape the jq program reads, in a temp file, because a
      # missing ledger must be an error and not an empty answer.
      TMP_DATA="$(mktemp)"
      ledger_file | jq -s . >"$TMP_DATA"
      printf '%s' "$TMP_DATA"
      ;;
  esac
}

trap 'rm -f "${TMP_DATA:-}"' EXIT
DATA="$(data_for "$REG")" || exit 1
[ -s "$DATA" ] || { say "empty registry payload for $REG"; exit 1; }

# `--data` is the generator's door into the SAME cache the query uses: one eval
# per registry per tree, whether a reader asks for rows or for the payload.
if [ -n "${DUMP_DATA:-}" ]; then
  printf '%s\n' "$DATA"
  exit 0
fi

# --- execution ---------------------------------------------------------------
JQ='
def sph:
  if type == "object" then to_entries[] | (.key, (.value | sph))
  elif type == "array" then .[] | sph
  elif . == null then ""
  else tostring end;
def txt: [sph] | join(" ");
def getf($f): getpath($f | split("."));
def hit($r; $spec):
  ($r | getf($spec.f)) as $v
  | ($spec.want | ascii_downcase) as $w
  | if $spec.k == "num" then (($v | tonumber?) // -1e18) >= ($w | tonumber)
    elif $spec.k == "bool" then
      (($v | tostring) == (if $w == "1" or $w == "yes" then "true" elif $w == "0" or $w == "no" then "false" else $w end))
    else
      ($v | txt | ascii_downcase) as $a
      | if $spec.k == "enum" then $a == $w else ($a | contains($w)) end
    end;
# A multi-word term is an AND over its words, not one literal substring. Speech
# names a doc path by its words — "the selector predesign" is
# `docs/selector-daemon-predesign.md` — and a substring test cannot see across the
# hyphens, so the term never matched and the question came back empty.
def touched($r; $term; $search):
  ([$search[] as $f | ($r | getf($f) | txt | ascii_downcase)] | join(" ")) as $hay
  | [$term | ascii_downcase | scan("[a-z0-9]+")] as $words
  | ($words | length) > 0 and all($words[]; . as $w | $hay | contains($w));

. as $raw
| (if $reg == "graph" then
     ($raw.nodes // [] | map(. as $n | . + {
        "in": ([($raw.edges // [])[] | select(.to == $n.id)] | length),
        "out": ([($raw.edges // [])[] | select(.from == $n.id)] | length)}))
   elif $reg == "inventory" then ($raw | to_entries | map(.value + {id: .key}))
   elif $reg == "notes" then ($raw | to_entries | map(.value + {id: .key}))
   elif $reg == "tasks" then
     ($raw.parsed // [] | map(. + {
        id: .name,
        build: ((.body // "") | test("nix build|nix-build|nixos-rebuild|darwin-rebuild|home-manager switch"))}))
   elif $reg == "ledger" then
     ($raw // [] | map(. as $e | ($e.jobs // {}) | to_entries | .[] | {
        id: .key, unit: .key, result: .value, ts: $e.ts, host: $e.host,
        state: $e.state, generation_age_h: ($e.generation_age_h // 0),
        disk_root: ($e.disk_pct.root // 0), psi_io: ($e.psi.io // 0)}))
   else [] end) as $rows
| $rows
| map(select(. as $r | [$filters[] | hit($r; .)] | all))
| (if $term == "" then . else map(select(. as $r | touched($r; $term; $search))) end)
'
# `all` over no filters is true, so a bare registry lists everything — a
# legitimate question ("what is in the notes registry"), not a refusal.

FILTER_JSON="$(for spec in ${FILTERS[@]+"${FILTERS[@]}"}; do
  n="${spec%%=*}"
  [ "$n" = "name" ] && n="id"
  jq -nc --arg f "$n" --arg w "${spec#*=}" --arg k "${KIND[$n]}" '{f: $f, want: $w, k: $k}'
done | jq -s .)"
SEARCH_JSON="$(searchable "$REG" | jq -R . | jq -s .)"
[ -n "$FIELDS" ] || FIELDS="$(default_fields "$REG")"
FIELDS_JSON="$(printf '%s' "$FIELDS" | tr ',' '\n' | sed '/^$/d' | jq -R . | jq -s .)"

# Stage 3 + projection. An empty result is a refusal at exit 3, so `p` is only
# ever measured over answered cases.
LIMITED="$(jq -c --arg reg "$REG" --argjson filters "$FILTER_JSON" \
  --argjson search "$SEARCH_JSON" --arg term "$TOUCHES" --argjson limit "$LIMIT" \
  --argjson fields "$FIELDS_JSON" \
  "$JQ | .[0:\$limit] | map(. as \$r | {id: \$r.id} + ([\$fields[] as \$f | {(\$f): (\$r | getf(\$f))}] | add))" \
  "$DATA")" || { say "query failed"; exit 1; }

COUNT="$(jq 'length' <<<"$LIMITED")"

if [ -n "$SHOW" ]; then
  want="${SHOW#*.}"
  if [ "$want" = "$SHOW" ] || [ -z "$want" ]; then
    refuse 2 schema "--show needs <registry>.<id> (got '$SHOW')"
  fi
  row="$(jq -c --arg reg "$REG" --argjson filters "$FILTER_JSON" \
    --argjson search "$SEARCH_JSON" --arg term "$TOUCHES" --arg id "$want" \
    --argjson fields "$FIELDS_JSON" \
    "$JQ | map(select(.id == \$id)) | .[0] | if . == null then null
      else . as \$r | {id: \$r.id} + ([\$fields[] as \$f | {(\$f): (\$r | getf(\$f))}] | add) end" \
    "$DATA")"
  [ "$row" != "null" ] || refuse 2 schema "no row '$want' in $REG"
  if [ "$JSON_MODE" = 1 ]; then
    jq -nc --arg reg "$REG" --arg id "$want" --argjson row "$row" \
      '{registry: $reg, id: $id, row: $row, elapsed_ms: '"$(elapsed)"'}'
  else
    jq -nc --arg reg "$REG" --arg id "$want" --argjson row "$row" \
      '{registry: $reg, id: $id, row: $row}' | toon -e
  fi
  exit 0
fi

if [ "$COUNT" -eq 0 ]; then
  # A message that names what was searched: the array is joined on purpose, and
  # mixing `${FILTERS[@]}` into a string glued the last filter to `touches=`.
  what="${FILTERS[*]:-}"
  [ -n "${TOUCHES:-}" ] && what="${what:+$what }touches=$TOUCHES"
  refuse 3 empty "no $REG row matches $(printf '%s' "$what")"
fi

# Stage 4: <=80 tokens (320 B, tokens = bytes/4) with a pointer per row, so the
# agent verifies in one cheap call instead of trusting a line of prose.
enc() { # rows-json -> TOON document
  jq -nc --arg reg "$REG" --argjson withheld "${2:-0}" --argjson rows "$1" \
    '{registry: $reg}
     + (if $withheld > 0 then {withheld: $withheld} else {} end)
     + {rows: $rows}' | toon -e
}

TEXT=""
for ((k = COUNT; k >= 1; k--)); do
  # The agent render is a FLAT table: an array or object cell is joined to one
  # clipped string so one wide row cannot cost the whole budget, and TOON keeps
  # tabulating instead of falling back to key-per-line. Types stay in --json.
  part="$(jq -c ".[0:$k] | map(with_entries(
    if .key == \"id\" then .
    elif (.value | type) == \"array\" then .value |= (map(tostring) | join(\"|\") | .[0:48])
    elif (.value | type) == \"object\" then .value |= (to_entries | map(\"\\(.key)=\\(.value | tostring)\") | join(\"|\") | .[0:48])
    elif (.value | type) == \"string\" then .value |= .[0:64]
    else . end))" <<<"$LIMITED")"
  TEXT="$(enc "$part" "$((COUNT - k))")"
  BYTES="$(printf '%s' "$TEXT" | wc -c)"
  if [ "$BYTES" -le 320 ]; then break; fi
done

if [ "$JSON_MODE" = 1 ]; then
  jq -nc --arg reg "$REG" --argjson rows "$LIMITED" --argjson ms "$(elapsed)" \
    --argjson bytes "$BYTES" --argjson shown "$k" \
    '{registry: $reg, count: ($rows | length), rows: $rows, shown: $shown,
      bytes: $bytes, elapsed_ms: $ms}'
  exit 0
fi

printf '%s\n' "$TEXT"
