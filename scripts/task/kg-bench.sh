#!/usr/bin/env bash
# kg-bench.sh — which router should `ops:ask` use? Measured, not assumed.
#
# The question this answers: for "English question -> one of six graph intents",
# is the in-repo heuristic engine good enough, does the hosted Jev beat it, and
# does anything justify a semantic layer beyond deterministic keywords?
#
# Runners (same labelled set, same six criteria, same state string):
#   keyword    the deterministic router in kg-ask.sh — rules, then the context
#              BUNDLE fallback when no rule matched (no model, no network)
#   heuristic  in-repo `systemone-decision` (modules/services/systemone/engine.py)
#   jev        TypeSafe Jev cloud, POST https://api.typesafe.ai/v1/systemone
#   decide     any Jev-compatible endpoint in KG_DECIDE_URL (e.g. the eisen
#              router, which forwards Authorization to Jev and falls back to
#              local Laya / Kev-4B)
#
# Intent is scored for every runner. Subject is scored only for runners that
# actually attempt it (keyword, jev, decide) — the local engine has no subject
# pass, so scoring it there would manufacture a 0 % it never tried for.
#
# Secrets: the TypeSafe key is read from sops into a variable and never printed;
# no header dump, no `set -x`. Without a key (or offline) Jev is SKIPPED, and
# the report says so rather than inventing a number.
#
# Usage: kg-bench.sh [--verbose] [--set rule|paraphrase|unnamed|both]
#        --set rule        vocabulary the keyword rules encode (default)
#        --set paraphrase  same questions WITHOUT that vocabulary
#        --set unnamed     questions that name NO node at all — the bundle's
#                          blind spot: it can only fire on a named node, so
#                          this set measures rule coverage and nothing else
#        --set both        the union of rule+paraphrase (the named sets); the
#                          unnamed set is NOT folded in — a score that mixes
#                          questions the bundle can answer with ones it cannot
#                          would hide the only difference that matters
#        VERBOSE=1 also prints per-question rows
#        KG_GRAPH=<path> use an existing graph JSON instead of evaluating
#        KG_DECIDE_URL=<url> add the router runner
# Exit: 0 = ran; 2 = usage; 1 = no runner produced results.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
SECRETS="${SECRETS:-$REPO/modules/secrets.yaml}"

# Sourced before the option loop because --help calls kg_usage() (the one help
# printer shared by the kg:* scripts).
. "${BASH_SOURCE[0]%/*}/lib/kg-graph.sh"
GRAPH="${KG_GRAPH:-}"
VERBOSE="${VERBOSE:-0}"
SET="${SET:-rule}"
JEV_URL="${JEV_URL:-https://api.typesafe.ai/v1/systemone}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --verbose) VERBOSE=1; shift ;;
    --set) SET="${2:-}"; shift 2 ;;
    --graph) export KG_GRAPH="${2:-}"; shift 2 ;;
    -h | --help) kg_usage "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "kg-bench: jq required" >&2; exit 2; }
command -v curl >/dev/null 2>&1 || { echo "kg-bench: curl required" >&2; exit 2; }

# --- the labelled sets ------------------------------------------------------
# `rule` is phrased in the vocabulary the keyword rules encode — it is the set
# the router was built against, and it flatters it. `paraphrase` asks the same
# questions without that vocabulary, which is exactly the case a language model
# is supposed to win. Only ever cite the set that was actually run.
#
# A caveat the scoring PRINTS rather than hides: an answer the router produced
# from the context bundle is flagged `bundle`, because its gold label was written
# from the same node-kind -> relation policy the bundle implements. Counting that
# as accuracy would be the bench grading itself, so the summary names how many of
# a runner's matches are bundle answers.
QS_RULE="$(cat <<'EOF'
what touches frieren	HOST_CONTEXT	host:frieren
docs and skills that mention eisen	HOST_CONTEXT	host:eisen
which docs mention qmd	SKILL_CONTEXT	skill:qmd
where is skill nix-eval used	SKILL_CONTEXT	skill:nix-eval
skills tagged nix	TAG_MEMBERS	-
which skills are tagged graph	TAG_MEMBERS	-
what is related to frieren	CO_MENTION	host:frieren
related hosts to poseidon	CO_MENTION	host:poseidon
what does docs/task-control-plane.md mention	DOC_CONTEXT	doc:docs/task-control-plane.md
what is in docs/closure-reduction.md	DOC_CONTEXT	doc:docs/closure-reduction.md
graph stats	STATS	-
how many skills are there	STATS	-
how many nodes and edges	STATS	-
what is the weather in berlin	UNKNOWN	-
EOF
)"

QS_PARAPHRASE="$(cat <<'EOF'
what should I read before touching minyx	HOST_CONTEXT	host:minyx
the repo notes that cover poseidon	HOST_CONTEXT	host:poseidon
tell me about fern	HOST_CONTEXT	host:fern
guides that lean on the qmd tooling	SKILL_CONTEXT	skill:qmd
how big is this thing	STATS	-
count the skills	STATS	-
who else shares documents with cassini	CO_MENTION	host:cassini
what is grouped under the nix label	TAG_MEMBERS	-
the file that documents the task namespaces	DOC_CONTEXT	doc:docs/task-control-plane.md
banana pancakes recipe	UNKNOWN	-
EOF
)"

# `unnamed` asks for the relation WITHOUT naming the thing it relates to, which
# is the one shape the context bundle structurally cannot handle: the bundle is
# "the question names a node but no rule matched a relation", so with no name it
# never fires and these questions fall through to UNKNOWN. That is the point of
# the set — it separates rule coverage from bundle coverage instead of letting
# the bundle's superset answer stand in for comprehension.
#
# Subject gold is `-` throughout, and that is not laziness: with no node named
# there is no subject to be right or wrong about, and scoring one would invent a
# 0 % the runner never attempted. These questions test INTENT ONLY. Several
# legitimately end in a "name a host" note rather than rows — a refusal to answer
# about nothing is correct behaviour, not a miss, so only the intent is scored.
QS_UNNAMED="$(cat <<'EOF'
how many edges does the whole thing have	STATS	-
count the links between pages and machines	STATS	-
which machines keep appearing in the same pages	CO_MENTION	-
what else gets discussed alongside a given machine	CO_MENTION	-
everything filed under the storage label	TAG_MEMBERS	-
list the labels in use	TAG_MEMBERS	-
summarise one page and everything it points at	DOC_CONTEXT	-
which guides refer to a tool this repo depends on	SKILL_CONTEXT	-
is there anything in here about my backup rotation	UNKNOWN	-
EOF
)"

case "$SET" in
  rule) QS="$QS_RULE" ;;
  paraphrase) QS="$QS_PARAPHRASE" ;;
  unnamed) QS="$QS_UNNAMED" ;;
  both) QS="$QS_RULE"$'\n'"$QS_PARAPHRASE" ;;
  *)
    echo "kg-bench: unknown set '$SET' (rule|paraphrase|unnamed|both)" >&2
    exit 2
    ;;
esac

# OUT_OF_SCOPE exists so a model can DECLINE. Without it the comparison is
# rigged: the deterministic router can answer "no query matched" and a 6-option
# choice cannot, so every off-topic question would score as a model failure.
# Gold `UNKNOWN` is normalised to `OUT_OF_SCOPE` for both runners.
CRITERIA='{
  "HOST_CONTEXT": "docs and skills that mention a host by name",
  "SKILL_CONTEXT": "docs that mention a skill, or where a skill is used",
  "TAG_MEMBERS": "skills that carry a tag, or the tags of a skill",
  "DOC_CONTEXT": "what one document mentions, its hosts and skills",
  "CO_MENTION": "hosts that appear in the same documents, related hosts",
  "STATS": "graph size, how many nodes and edges, counts",
  "OUT_OF_SCOPE": "not a question about this repository knowledge graph"
}'

# --- graph (subject candidates + keyword runner) ----------------------------
GRAPH="$(kg_graph_path)" || exit 1
[ -s "$GRAPH" ] || { echo "kg-bench: no graph at $GRAPH" >&2; exit 1; }

candidates_for() {
  jq -c --arg q "$1" '
    def toks: ascii_downcase | [scan("[a-z0-9_-]+")];
    def sig: map(select(. != "md" and . != "docs" and . != "nixconfig" and . != "skills" and . != "agents"));
    def name_tokens:
      if .type == "doc"
      then (.path | split("/") | last | sub("md$"; "") | toks | sig)
      else (.label | toks | sig)
      end;
    ($q | toks) as $qt
    | [ .nodes[] | select(.type == "host" or .type == "skill" or .type == "doc") ]
    | ( [ .[] | select(name_tokens as $lt | ($lt | length) > 0 and (($lt - $qt) | length) == 0) ] ) as $exact
    | ( [ .[] | select(name_tokens | any(. as $t | $qt | index($t))) ] ) as $loose
    | ((if ($exact | length) > 0 then $exact else $loose end) | map(.id) | .[:20])
  ' "$GRAPH"
}

# --- secrets (never printed) ------------------------------------------------
key=""
if command -v sops >/dev/null 2>&1 && [ -r "$SECRETS" ]; then
  # The key is an INDENTED `KEY=value` line inside the mapping, so anchor on
  # whitespace-then-name rather than the line start (there is no `yq` shape here
  # to lean on: the file is dotenv-style blocks).
  key="$(sops -d "$SECRETS" 2>/dev/null | sed -n 's/^[[:space:]]*TYPESAFE_API_KEY=//p' | head -1 || true)"
fi

now_ms() { date +%s%3N; }

# --- runners: each prints "intent<TAB>confidence<TAB>subject<TAB>ms" --------
# 5th field: `bundle` marks an answer that came from the node-kind -> relation
# policy rather than from a rule. It is not an error — but the labelled set was
# written by the same person who wrote that policy, so counting it as accuracy
# would be the bench grading itself. It is reported separately for that reason.
run_keyword() {
  local q="$1" out
  out="$(KG_NO_MODEL=1 KG_GRAPH="$GRAPH" bash "$REPO/scripts/task/kg-ask.sh" --json "$q" 2>/dev/null)" || return 1
  jq -r '[(.intent),
          (.confidence | tostring),
          (.subject.id // "-"),
          "0",
          (if .bundle then "bundle" else "" end)] | @tsv' <<<"$out"
}

run_heuristic() {
  local q="$1" t0 t1 out
  t0="$(now_ms)"
  out="$(systemone-decision --model julia-1 query --type choice --state "$q" \
    --prompt "Which knowledge-graph query answers this question?" \
    --options "HOST_CONTEXT: docs and skills that mention a host by name" \
    "SKILL_CONTEXT: docs that mention a skill, or where a skill is used" \
    "TAG_MEMBERS: skills that carry a tag, or the tags of a skill" \
    "DOC_CONTEXT: what one document mentions, its hosts and skills" \
    "CO_MENTION: hosts that appear in the same documents, related hosts" \
    "STATS: graph size, how many nodes and edges, counts" \
    "OUT_OF_SCOPE: not a question about this repository knowledge graph" 2>/dev/null)" || return 1
  t1="$(now_ms)"
  jq -r --arg ms "$((t1 - t0))" '"\(.decision | split(":")[0])\t\(.confidence)\t-\t\($ms)"' <<<"$out"
}

# Intent AND subject in ONE request: two questions, one forward pass — that is
# what the /v1/systemone contract exists for, and it is why the cloud path can
# afford to be called per question.
run_http() {
  local url="$1" auth="$2" q="$3" cands body out t0 t1 local_subject=""
  cands="$(candidates_for "$q")"
  # One candidate is already decided (exact-name match) — asking a 1-option
  # question would waste a token budget and, if skipped, must not be scored as a
  # wrong answer. Only genuine ambiguity goes to the model.
  if [ "$(jq -r 'length' <<<"$cands")" = "1" ]; then
    local_subject="$(jq -r '.[0]' <<<"$cands")"
  fi
  # `model` is REQUIRED by the hosted API (422 without it) and the fleet's own
  # router defaults it to `jev-latest` (main.go:241) — the same value is used
  # here so the bench and the router ask the same model.
  body="$(jq -cn --arg q "$q" --arg model "${KG_DECIDE_MODEL:-jev-latest}" --argjson crit "$CRITERIA" --argjson cands "$cands" '
    {model: $model, state: {question: $q},
     questions: ({intent: {type: "choice",
                           instructions: "Which knowledge-graph query answers this question?",
                           criteria: $crit}} +
                 (if ($cands | length) > 1
                  then {subject: {type: "choice",
                                  instructions: "Which node does this question refer to?",
                                  criteria: ($cands | map({(.): .}) | add)}}
                  else {} end))}')" || return 1

  # Retry once: a 502/000 on the first call is documented cold-start behaviour
  # (decision-picker skill), and the bench must not score a cold start as wrong.
  local attempt=0
  while :; do
    attempt=$((attempt + 1))
    t0="$(now_ms)"
    if [ -n "$auth" ]; then
      out="$(curl -s -m 30 -H 'Content-Type: application/json' -H "Authorization: Bearer $auth" -d "$body" "$url" 2>/dev/null)" || out=""
    else
      out="$(curl -s -m 30 -H 'Content-Type: application/json' -d "$body" "$url" 2>/dev/null)" || out=""
    fi
    t1="$(now_ms)"
    jq -e '.answers' >/dev/null 2>&1 <<<"$out" && break
    [ "$attempt" -ge 2 ] && return 1
  done

  jq -r --arg ms "$((t1 - t0))" --arg local "$local_subject" '
    [ (.answers.intent.choice // "?"),
      ((.answers.intent.confidence // 0) | tostring),
      (.answers.subject.choice // (if $local == "" then "-" else $local end)),
      $ms ] | @tsv' <<<"$out" 2>/dev/null
}

# --- scoring ----------------------------------------------------------------
FAILED=0

run_runner() {
  local name="$1" mode="$2" target="$3" auth="$4" scores_subject="$5"
  local hit=0 n=0 subj_hit=0 subj_n=0 conf_sum=0 ms_sum=0 q gold gsubj
  local bundle_n=0 bundle_hit=0
  local rows="" out intent conf subj ms policy

  while IFS=$'\t' read -r q gold gsubj; do
    [ -n "${q:-}" ] || continue
    if [ "$mode" = "http" ]; then
      out="$(run_http "$target" "$auth" "$q")" || { echo "  [$name] no answer for: $q" >&2; FAILED=1; return 1; }
    else
      out="$($target "$q")" || { echo "  [$name] runner failed on: $q" >&2; FAILED=1; return 1; }
    fi
    IFS=$'\t' read -r intent conf subj ms policy <<<"$out"
    # Both sides speak OUT_OF_SCOPE; the keyword router calls it UNKNOWN.
    [ "$intent" = "UNKNOWN" ] && intent="OUT_OF_SCOPE"
    [ "$gold" = "UNKNOWN" ] && gold="OUT_OF_SCOPE"

    n=$((n + 1))
    if [ "$intent" = "$gold" ]; then hit=$((hit + 1)); mark="ok"; else mark="MISS"; fi
    if [ "$policy" = "bundle" ]; then
      bundle_n=$((bundle_n + 1))
      [ "$intent" = "$gold" ] && bundle_hit=$((bundle_hit + 1))
    fi
    if [ "$scores_subject" = 1 ] && [ "$gsubj" != "-" ]; then
      subj_n=$((subj_n + 1))
      [ "$subj" = "$gsubj" ] && subj_hit=$((subj_hit + 1))
    fi
    conf_sum="$(awk -v a="$conf_sum" -v b="${conf:-0}" 'BEGIN{print a+b}')"
    ms_sum="$(awk -v a="$ms_sum" -v b="${ms:-0}" 'BEGIN{print a+b}')"
    rows+="$(printf '  %-9s %-4s gold=%-13s got=%-13s %s\n' "$name" "$mark" "$gold" "$intent" "$q")"$'\n'
  done <<<"$QS"

  [ "$n" -gt 0 ] || return 1
  [ "$VERBOSE" = 1 ] && printf '%s' "$rows"
  [ "$scores_subject" = 1 ] && [ "$subj_n" -gt 0 ] && subj_txt="$subj_hit/$subj_n" || subj_txt="n/a"
  SUMMARY+="$(printf '  %-10s intent %2d/%2d = %3d%%   subject %-5s  mean_conf %.2f  mean_latency %4.0f ms\n' \
    "$name" "$hit" "$n" "$((hit * 100 / n))" "$subj_txt" \
    "$(awk -v a="$conf_sum" -v b="$n" 'BEGIN{printf "%.2f", a/b}')" \
    "$(awk -v a="$ms_sum" -v b="$n" 'BEGIN{printf "%.0f", a/b}')")"$'\n'
  # Named, not hidden: N of these matches are the bundle policy agreeing with a
  # label written from the same policy. The number is part of the result, so a
  # reader can discount it instead of having to trust the total.
  if [ "$bundle_n" -gt 0 ]; then
    SUMMARY+="$(printf '  %-10s ^ of %d matches, %d are bundle answers (node-kind policy; the gold was written with it, so not independent evidence)\n' \
      "$name" "$hit" "$bundle_hit")"$'\n'
  fi
  return 0
}

SUMMARY=""
printf 'kg-bench — set %s, %d labelled questions, graph %s\n' "$SET" "$(grep -c . <<<"$QS")" "$GRAPH"
printf '  criteria: HOST_CONTEXT SKILL_CONTEXT TAG_MEMBERS DOC_CONTEXT CO_MENTION STATS\n\n'
# Stated up front for this set, so a good number here is not read as the bundle
# working. Measured rather than assumed: the tier-1/3 node bundle cannot fire
# (no name to resolve), but the TAG tier can, because it scans the question's
# tokens for a tag rather than resolving a node — "filed under the storage
# label" does reach tag:storage. The summary's bundle line prints the real count.
[ "$SET" = "unnamed" ] && printf '  note: no question here names a node, so only the tag tier of the bundle can fire — rule coverage dominates this set\n\n'

run_runner keyword fn run_keyword "" 1 || true
run_runner heuristic fn run_heuristic "" 0 || true

if [ -n "$key" ]; then
  run_runner jev http "$JEV_URL" "$key" 1 || true
else
  SUMMARY+="  jev        SKIPPED (no TYPESAFE_API_KEY readable from sops)"$'\n'
fi

if [ -n "${KG_DECIDE_URL:-}" ]; then
  run_runner decide http "$KG_DECIDE_URL" "${KG_DECIDE_TOKEN:-}" 1 || true
else
  SUMMARY+="  decide     SKIPPED (KG_DECIDE_URL unset — e.g. http://eisen:8000/v1/decisions)"$'\n'
fi

printf '%s' "$SUMMARY"

# Where did the keyword runner's answers come from? A scorer sees only the
# intent, so a fallback that silently took over the whole set would look the same
# as the rules doing their job. This prints the provenance (route + intent,
# counted) instead.
census="$(
  printf '%s\n' "$QS" | cut -f1 | while IFS= read -r q; do
    [ -n "$q" ] || continue
    out="$(KG_NO_MODEL=1 KG_GRAPH="$GRAPH" bash "$REPO/scripts/task/kg-ask.sh" --json "$q" 2>/dev/null)" || out=""
    printf '%s %s\n' "$(jq -r '.route // "none"' <<<"$out" 2>/dev/null)" "$(jq -r '.intent // "UNKNOWN"' <<<"$out" 2>/dev/null)"
  done | sort | uniq -c | sort -rn
)"
printf '  routing census (count route intent):\n'
printf '%s\n' "$census" | sed 's/^/    /'

[ "$FAILED" = 0 ] || echo "(some runners failed or were skipped — see stderr above)" >&2
exit 0
