#!/usr/bin/env bash
# kg-ask.sh — a question in English → one of six graph queries → jq over the graph.
#
# Why this shape
# --------------
# `nix eval` already compiles the graph into a static JSON document
# (`.#knowledgeGraph.graph`, ~50 KB). That is *better* than a Cypher server for
# this fleet: no JVM, no page-cache competition on an 11 GiB NAS, and every
# question is a `jq` filter over a file that is already in the store. The one
# thing a static file cannot do is guess *which* filter the question wants.
#
# That guess is made in three DETERMINISTIC steps, and never by a model:
#   1. keyword rules   "mention" → SKILL_CONTEXT, "touch" → HOST_CONTEXT
#   2. context bundle  no rule matched, but the question NAMES a node — return
#                      everything connected to that node rather than guess which
#                      of six relations was meant (this is what fixed the
#                      paraphrases; see the `bundle` block below)
#   3. UNKNOWN         nothing matched: print the six patterns as a menu
#   jq                 the actual graph query                               (~5 ms)
#   nix eval           only when the cache is cold (once per revision)
#
# A model is NOT in this path. It used to be the step-2 fallback and was removed
# on 2026-10-19, on evidence that is deliberately split, because one of the two
# numbers is circular:
#   rule set       14/14 at 0 ms (labels written from the six intents, so
#                  independent of the implementation) vs Jev 13/14 at ~330 ms.
#   paraphrase     rules alone 6/10; 10/10 with the bundle — but FOUR of those
#                  are bundle answers whose gold encodes the same node-kind ->
#                  relation policy the bundle implements. That is coverage, not
#                  comprehension, and `ops:bench:kg` prints the count next to the
#                  score instead of folding it into a headline.
#   unnamed        rules 4/9, Jev 7/9 (2026-10-19) — questions that name NO node,
#                  which is the bundle's structural blind spot: it resolves a
#                  name and returns that node's context, so with no name there is
#                  nothing to resolve. The split matters more than the totals:
#                  the rules' five misses are UNKNOWN (a visible decline), while
#                  Jev's two are confident wrong intents, one of them marking an
#                  off-topic question DOC_CONTEXT. A caller can act on a decline;
#                  it cannot see a confident wrong relation.
# The policy rests on what is not circular: a bundle cannot mis-pick a relation
# (it returns the superset and lets the caller narrow), it needs no key and no
# network, and 0 ms beats ~330 ms.
# KG_DECIDE_ALWAYS=1 still opts in to a Jev-compatible endpoint as an agreement
# check (recorded in `route`), which is what `ops:ask:jev` sets up.
#
# Usage
# -----
#   kg-ask.sh "what touches frieren"            # human table
#   kg-ask.sh --json "which docs mention qmd"   # machine-readable
#   kg-ask.sh --refresh "skills tagged nix"     # ignore the cached graph
#   kg-ask.sh --graph /nix/store/...-kg.json "…"
#
# Env: KG_DECIDE_URL=<url>   Jev-compatible endpoint, consulted ONLY with
#              KG_DECIDE_ALWAYS=1 (agreement check).
#      KG_DECIDE_TOKEN=<key> Bearer token for that endpoint (never printed).
#              ops:ask:jev sets it from sops for you.
#      KG_NO_MODEL=1         never call any model (already the default path)
#      KG_GRAPH=<path>       use this graph file (no eval, no cache)
#      KG_DECIDE_MODEL=      model field for the endpoint (default jev-latest)
#      XDG_CACHE_HOME        cache root (default ~/.cache)
#
# Exit: 0 = answered (including UNKNOWN, which prints the pattern menu);
#       2 = usage error; 1 = graph could not be produced.
set -euo pipefail


# Shared with the other kg:* scripts. Sourced BEFORE the option loop, because
# `--help` calls kg_usage() from inside it.
. "${BASH_SOURCE[0]%/*}/lib/kg-graph.sh"

format=text
refresh=0
question=""

usage() {
  kg_usage "${BASH_SOURCE[0]}"
  exit "${1:-0}"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) format=json; shift ;;
    --text) format=text; shift ;;
    --refresh) refresh=1; shift ;;
    --graph) export KG_GRAPH="${2:-}"; shift 2 ;;
    -h | --help) usage 0 ;;
    --*) echo "unknown option: $1" >&2; usage 2 ;;
    *) question="$1"; shift ;;
  esac
done

[ -n "$question" ] || usage 2

command -v jq >/dev/null 2>&1 || { echo "kg-ask: jq is required" >&2; exit 1; }

out_file="${TMPDIR:-/tmp}/kg-ask.$$.json"
trap 'rm -f "$out_file"' EXIT

# --- graph resolution -------------------------------------------------------
# Shared with the other kg:* scripts (lib/kg-graph.sh, sourced above): cached per
# clean revision, re-evaluated on a dirty tree, KG_GRAPH/--graph short circuits
# both.
graph="$(kg_graph_path "$refresh")" || exit 1
[ -s "$graph" ] || { echo "kg-ask: no graph at $graph" >&2; exit 1; }

# --- candidate nodes named in the question ----------------------------------
# TWO passes on purpose. An exact label hit ("frieren") beats a partial one
# ("frieren-access"), so a question about a host is not silently answered about
# a document that mentions it, and the model is only consulted when the exact
# set is genuinely ambiguous.
candidates="$(
  jq -c --arg q "$question" '
    def toks: ascii_downcase | [scan("[a-z0-9_-]+")];
    # Path STRUCTURE is not vocabulary: a skill lives at .agents/skills/<name>,
    # so tokenizing the path makes every skill match the word "skills". Only the
    # label (plus a document filename stem) names the thing.
    def sig: map(select(. != "md" and . != "docs" and . != "nixconfig" and . != "skills" and . != "agents"));
    # The node NAME, not its prose. A document label is its first heading —
    # "Closure Reduction ... toward nix shell" — so matching that makes every
    # doc which says "nix" a candidate for "skills tagged nix". Documents are
    # named by their filename stem instead; hosts and skills ARE their label.
    def name_tokens:
      if .type == "doc"
      then (.path | split("/") | last | sub("md$"; "") | toks | sig)
      else (.label | toks | sig)
      end;
    ($q | toks) as $qt
    | [ .nodes[] | select(.type == "host" or .type == "skill" or .type == "doc") ]
    # ($lt|length) > 0 matters: a name made entirely of ignored words would
    # otherwise be a subset of every question and win the exact pass.
    | ( [ .[] | select(name_tokens as $lt
             | ($lt | length) > 0 and (($lt - $qt) | length) == 0) ] ) as $exact
    | ( [ .[] | select(name_tokens | any(. as $t | $qt | index($t))) ] ) as $loose
    | {exact_n: ($exact | length),
       cands: ((if ($exact | length) > 0 then $exact else $loose end) | map({id, type, label}) | .[:20])}
  ' "$graph"
)"
exact_n="$(jq -r '.exact_n' <<<"$candidates")"
candidates="$(jq -c '.cands' <<<"$candidates")"
cand_n="$(jq -r 'length' <<<"$candidates")"

# --- intent ----------------------------------------------------------------
# Option text carries the vocabulary on purpose: the decision engine scores the
# option's words against the question, so "docs and skills that mention a host"
# is a better option than "HOST_CONTEXT".
intent_options=(
  "HOST_CONTEXT: docs and skills that mention a host by name"
  "SKILL_CONTEXT: docs that mention a skill, or where a skill is used"
  "TAG_MEMBERS: skills that carry a tag, or the tags of a skill"
  "DOC_CONTEXT: what one document mentions, its hosts and skills"
  "CO_MENTION: hosts that appear in the same documents, related hosts"
  "STATS: graph size, how many nodes and edges, counts"
  # Lets the model DECLINE instead of forcing one of six answers onto an
  # off-topic question (kg-bench does the same, so the numbers match). Mapped
  # back to UNKNOWN below.
  "OUT_OF_SCOPE: not a question about this repository knowledge graph"
)
decision='{"model":"none","confidence":0.0,"decision":"","probabilities":{}}'
have_model=0
model_intent=""
model_conf="0"

# ESCALATION, NOT A PER-QUERY CALL.
#
# Measured with `task ops:bench:kg` (2026-10-19): the deterministic router is
# 14/14 on questions phrased in its own vocabulary and 6/10 on paraphrases;
# hosted Jev is 13/14 and 9/10 respectively at ~350 ms per call. So a per-query
# call spends a round trip and a cloud dependency re-deriving answers the rules
# already produce, and buys nothing on the traffic that dominates agent use.
# The call is therefore made at ONE point: when the rules return nothing at all
# (the 4/10 paraphrase case, where Jev is the only thing that answers).
# That is also why the `unnamed` set (rules 4/9, Jev 7/9) does NOT reopen the
# question: Jev's advantage there comes partly from answering questions the
# graph cannot answer at all — it labelled an off-topic question DOC_CONTEXT
# rather than declining — which is the failure mode a caller cannot detect.
# KG_DECIDE_ALWAYS=1 opts back into the old always-consult agreement check.
consult_model() {
  # Preferred backend: a Jev-compatible HTTP endpoint (`/v1/systemone`). That is
  # hosted Jev or the eisen router, which forwards the client's Authorization to
  # Jev and falls back to local Laya/Kev-4B. Configured, never assumed: without
  # KG_DECIDE_URL there is no network call at all.
  if [ -n "${KG_DECIDE_URL:-}" ]; then
    criteria="$(printf '%s\n' "${intent_options[@]}" |
      jq -Rn '[inputs | split(":") | {(.[0]): (.[1:] | join(":") | ltrimstr(" "))}] | add')"
    payload="$(jq -cn --arg q "$question" --arg model "${KG_DECIDE_MODEL:-jev-latest}" --argjson crit "$criteria" '
      {model: $model, state: {question: $q},
       questions: {intent: {type: "choice",
                            instructions: "Which knowledge-graph query answers this question?",
                            criteria: $crit}}}')"
    # `|| out=""` is load-bearing: without it a configured-but-unreachable
    # endpoint (curl exit 7) aborts the whole query under `set -e`, turning a
    # degradation into a failure. A dead model must cost the hint, not the answer.
    if [ -n "${KG_DECIDE_TOKEN:-}" ]; then
      out="$(curl -s -m 25 -H 'Content-Type: application/json' -H "Authorization: Bearer $KG_DECIDE_TOKEN" -d "$payload" "$KG_DECIDE_URL" 2>/dev/null)" || out=""
    else
      out="$(curl -s -m 25 -H 'Content-Type: application/json' -d "$payload" "$KG_DECIDE_URL" 2>/dev/null)" || out=""
    fi
    if jq -e '.answers.intent.choice' >/dev/null 2>&1 <<<"$out"; then
      decision="$(jq -c '{model: (.model // "endpoint"), decision: .answers.intent.choice, confidence: (.answers.intent.confidence // 0), probabilities: (.answers.intent.probabilities // {})}' <<<"$out")"
      have_model=1
    fi
  fi
  # No endpoint, no check. There used to be an offline branch here that shelled
  # out to `systemone-decision`; that binary is a hash-embedding heuristic
  # (5/14 on the rule set, 1/10 on paraphrases), so calling it "the model" was
  # the same mislabelling this file has been cleaning up. `ops:bench:kg` still
  # measures it, as the `heuristic` runner.
  model_intent="$(jq -r '.decision // "" | split(":")[0]' <<<"$decision")"
  model_conf="$(jq -r '.confidence // 0' <<<"$decision")"
}

# Keyword routing: the fallback when the model is absent, and the tie-break when
# it is not confident. Deliberately dumb — each rule is one phrase, ordered so a
# specific phrase ("mention") wins over a generic one ("doc").
kw_intent() {
  local q
  q="$(tr '[:upper:]' '[:lower:]' <<<"$1")"
  case "$q" in
    *"how many"* | *"how big"* | *stats* | *count* | *size*) echo "STATS" ;;
    *related* | *"co-mention"* | *sibling* | *"same doc"* | *share* | *"connected"*) echo "CO_MENTION" ;;
    *tag*) echo "TAG_MEMBERS" ;;
    *mention* | *"where is"* | *"which docs"* | *"what docs"* | *"used by"*) echo "SKILL_CONTEXT" ;;
    *"what does"* | *"what is in"* | *document*) echo "DOC_CONTEXT" ;;
    *touch* | *host* | *"who uses"*) echo "HOST_CONTEXT" ;;
    *) echo "" ;;
  esac
}

# Routing is DETERMINISTIC; the model is an advisory second opinion.
#
# Measured 2026-10-19 with the in-repo engine (`systemone-decision`): over this
# six-intent taxonomy its `choice` lands at or near chance — 2/8 questions right
# with equal-length options, 3/8 at sub-threshold confidence otherwise, and the
# per-intent `noul` probabilities sit at 0.50-0.67 with no separation. That is
# the honest reading: `modules/services/systemone/engine.py` is a hash-embedding
# heuristic with a softmax head, not mmBERT, so it cannot be the routing
# authority for a 225-node graph without being wrong quietly.
#
# So: keywords answer, and the model is now only an opt-in agreement check
# (`KG_DECIDE_ALWAYS=1`). The model USED to supply the intent when no keyword
# rule matched, and that was removed on 2026-10-19 — it was answering a question
# the graph answers better.
#
# The reasoning, because it is the whole design: in every paraphrase the rules
# missed, the question still NAMED A NODE. "what should I read before touching
# minyx" resolves to host:minyx; only the relation was ambiguous. Asking a
# classifier to pick one of six relations from that is asking it to guess when
# the honest answer is "all of them" — so the fallback returns the node's whole
# context (mentions, related hosts, tags) instead of one relation. Offline,
# deterministic, no key, and it cannot mis-pick a relation because it declines to
# pick one. `route=bundle` records that. See `ops:bench:kg` for the numbers.
intent="$(kw_intent "$question")"
route="keyword"
confidence="0.0"
bundle=0
# The opt-in model check runs LATER, after the bundle fallback, and only for
# questions a keyword rule answered — see the `KG_DECIDE_ALWAYS` block below.

# --- subject ---------------------------------------------------------------
subject="null"
subject_route="exact"
[ "$exact_n" -gt 0 ] || subject_route="loose"
if [ "$cand_n" -eq 1 ]; then
  subject="$(jq -c '.[0]' <<<"$candidates")"
fi
# Ambiguous candidates (several nodes named): take the first, exact match first
# then host > skill > doc as compiled, and say so via `via: first-of-N` rather
# than answering about nothing. There used to be a model call here to rank them;
# it was removed with the rest of the routing model, and the bench never scored
# a subject pass for it, so nothing is lost by the deterministic pick — and the
# caller can always ask the explicit pattern for any other candidate.
if [ "$subject" = "null" ] && [ "$cand_n" -ge 1 ]; then
  subject="$(jq -c '.[0]' <<<"$candidates")"
  subject_route="first-of-$cand_n"
fi

subj_id="$(jq -r 'if . == null then "" else .id end' <<<"$subject")"
subj_type="$(jq -r 'if . == null then "" else .type end' <<<"$subject")"

# A named subject overrides a mismatched intent: "what touches frieren" routed
# to DOC_CONTEXT would otherwise look for a document named frieren.
if [ -n "$subj_id" ]; then
  # A named subject is strong evidence about the intent, so this table is
  # symmetric in subject type. The bench caught the missing direction: "docs and
  # skills that mention eisen" was routed SKILL_CONTEXT (the word "mention") even
  # though it names a HOST — one of the two questions the keyword router missed.
  case "$intent:$subj_type" in
    DOC_CONTEXT:host | DOC_CONTEXT:skill) intent="HOST_CONTEXT" ;;
    HOST_CONTEXT:doc | SKILL_CONTEXT:doc) intent="DOC_CONTEXT" ;;
    SKILL_CONTEXT:host) intent="HOST_CONTEXT" ;;
    HOST_CONTEXT:skill) intent="SKILL_CONTEXT" ;;
    CO_MENTION:skill | CO_MENTION:doc) intent="SKILL_CONTEXT" ;;
    TAG_MEMBERS:host) intent="HOST_CONTEXT" ;;
  esac
fi

# --- bundle fallback --------------------------------------------------------
# Runs ONLY when no keyword rule matched. Ordering is deliberate:
#   1. an EXACT node name (frieren, qmd, docs/x.md)   -> that node's context
#   2. an exact TAG token ("...under the nix label")  -> tag membership
#   3. a LOOSE node name ("nix" matches skill nix-eval) -> that node's context
#   4. nothing                                        -> UNKNOWN + the pattern menu
# Tags sit between the two node tiers because they are the one node type the
# candidate scan cannot see (candidates are hosts/skills/docs), and a bare tag
# word is strong evidence the question is about membership, not about a node.
# Without this tier "what is grouped under the nix label" answers about
# skill:nix-eval, which is the wrong question asked confidently.
if [ -z "$intent" ]; then
  if [ -n "$subj_id" ] && [ "$exact_n" -gt 0 ]; then
    bundle=1
  else
    # No exact node name, so the tag lookup runs — and only then, because it is
    # a full scan and an exact name is the stronger signal. Tags are the one node
    # type the candidate scan cannot see, so a bare tag word is checked here
    # rather than in the candidate query.
    tag_token="$(jq -r --arg q "$question" '
      (.nodes | map(select(.type == "tag") | .id | sub("^tag:"; ""))) as $tags
      | [[ $q | ascii_downcase | scan("[a-z0-9_-]+") ] | .[]
         | select(. as $t | $tags | index($t))] | .[0] // ""
    ' "$graph")"
    if [ -n "$tag_token" ]; then
      bundle=1
      subj_id="tag:$tag_token"
      subj_type="tag"
      subject="$(jq -c -n --arg id "tag:$tag_token" \
        '{id: $id, type: "tag", label: ($id | sub("^tag:"; ""))}')"
      subject_route="bundle-tag"
    elif [ -n "$subj_id" ]; then
      bundle=1
      subject_route="bundle-loose"
    fi
  fi

  if [ "$bundle" = 1 ]; then
    case "$subj_type" in
      host) intent="HOST_CONTEXT" ;;
      skill) intent="SKILL_CONTEXT" ;;
      doc) intent="DOC_CONTEXT" ;;
      tag) intent="TAG_MEMBERS" ;;
    esac
    route="bundle"
  fi
fi
[ -n "$intent" ] || intent="UNKNOWN"

# --- opt-in model check (KG_DECIDE_ALWAYS=1) --------------------------------
# Applies ONLY to a question a keyword rule answered, and it is a check, not a
# vote: the rule already decided, and this records whether the model agreed
# (`route: agreed`) or not (`keyword+disagree`). Deliberately NOT run for
# bundle/unmatched questions — there is no single relation to agree with, and
# `ops:ask:jev` should not imply one. `consulted=false` in the output is how a
# caller sees that no call happened.
if [ "$route" = "keyword" ] && [ "${KG_DECIDE_ALWAYS:-0}" = "1" ] && [ "${KG_NO_MODEL:-0}" != "1" ]; then
  consult_model
  if [ "$have_model" = 1 ] && awk -v c="$model_conf" 'BEGIN{exit !(c >= 0.55)}'; then
    if [ "$model_intent" = "$intent" ]; then
      route="agreed"
      confidence="$model_conf"
    else
      route="keyword+disagree"
    fi
  fi
fi

# --- dispatch --------------------------------------------------------------
results='[]'
note=""
case "$intent" in
  HOST_CONTEXT)
    if [ "$subj_type" = "host" ]; then
      results="$(jq -c --arg h "$subj_id" '[.edges[] | select(.to == $h) | .from] | unique' "$graph")"
    elif [ "$subj_type" = "skill" ]; then
      results="$(jq -c --arg s "$subj_id" '[.edges[] | select(.to == $s and .type == "mentions") | .from] | unique' "$graph")"
    else
      note="name a host, e.g. -- \"what touches frieren\""
    fi
    ;;
  SKILL_CONTEXT)
    if [ "$subj_type" = "skill" ]; then
      results="$(jq -c --arg s "$subj_id" '[.edges[] | select(.to == $s and .type == "mentions") | .from] | unique' "$graph")"
    elif [ "$subj_type" = "doc" ]; then
      results="$(jq -c --arg d "$subj_id" '[.edges[] | select(.from == $d and (.to | startswith("skill:"))) | .to] | unique' "$graph")"
    else
      results="$(jq -c '[.edges[] | select(.type == "mentions" and (.to | startswith("skill:"))) | .to]
        | group_by(.) | map({id: .[0], docs: length}) | sort_by(-.docs) | .[:10]' "$graph")"
      note="no skill named in the question; top skills by document coverage below"
    fi
    ;;
  TAG_MEMBERS)
    if [ "$subj_type" = "skill" ]; then
      results="$(jq -c --arg s "$subj_id" '[.edges[] | select(.from == $s and .type == "tagged") | .to] | unique' "$graph")"
    elif [ "$subj_type" = "tag" ]; then
      results="$(jq -c --arg t "$subj_id" '[.edges[] | select(.to == $t and .type == "tagged") | .from] | unique' "$graph")"
    else
      # A tag is often written bare ("skills tagged nix") which the node scan
      # cannot see, because candidates are hosts/skills/docs only.
      want="$(tr '[:upper:]' '[:lower:]' <<<"$question" | tr -cs 'a-z0-9_-' '\n' | tail -1)"
      results="$(jq -c --arg t "tag:$want" \
        '[.edges[] | select(.to == $t and .type == "tagged") | .from] | unique' "$graph")"
      if [ "$(jq -r 'length' <<<"$results")" = "0" ]; then
        results="$(jq -c '[.nodes[] | select(.type == "tag") | .id] as $tags
          | [$tags[] as $t | {id: $t, skills: ([.edges[] | select(.to == $t)] | length)}]
          | sort_by(-.skills) | .[:10]' "$graph")"
        note="no tag matched \"$want\"; most-used tags below"
      fi
    fi
    ;;
  DOC_CONTEXT)
    if [ "$subj_type" = "doc" ]; then
      results="$(jq -c --arg d "$subj_id" '[.edges[] | select(.from == $d) | .to] | unique' "$graph")"
    else
      results="$(jq -c '[.nodes[] | select(.type == "doc") | .id] | unique' "$graph")"
      note="name a document, e.g. -- \"what does docs/task-control-plane.md mention\""
    fi
    ;;
  CO_MENTION)
    if [ "$subj_type" = "host" ]; then
      results="$(jq -c --arg h "$subj_id" '
        [.edges[] | select(.to == $h) | .from] as $docs
        | [.edges[] | select(.type == "mentions" and (.to | startswith("host:")) and .to != $h
             and (.from as $f | $docs | index($f))) | .to]
        | group_by(.) | map({id: .[0], docs: length}) | sort_by(-.docs)' "$graph")"
    else
      note="name a host, e.g. -- \"what is related to frieren\""
    fi
    ;;
  STATS)
    results="$(jq -c '[.stats + {mentions: ([.edges[] | select(.type == "mentions")] | length), tagged: ([.edges[] | select(.type == "tagged")] | length)}]' "$graph")"
    ;;
  *)
    intent="UNKNOWN"
    results="$(jq -c '[.edges[] | select(.type == "mentions" and (.to | startswith("skill:"))) | .to]
      | group_by(.) | map({id: .[0], docs: length}) | sort_by(-.docs) | .[:5]' "$graph")"
    note="no query matched. Try \"what touches <host>\", \"which docs mention <skill>\", \"skills tagged <tag>\", \"what is related to <host>\", or \"graph stats\"."
    ;;
esac

# A bundle answers several relations at once: the primary one above, plus the
# neighbours that make it a bundle rather than a guess. Kept in `related` (not
# merged into `results`) so a caller can tell which part was the direct answer.
related='[]'
if [ "$bundle" = 1 ]; then
  case "$subj_type" in
    host)
      related="$(jq -c --arg h "$subj_id" '
        [.edges[] | select(.to == $h) | .from] as $docs
        | [.edges[] | select(.type == "mentions" and (.to | startswith("host:")) and .to != $h
             and (.from as $f | $docs | index($f))) | .to]
        | group_by(.) | map({id: .[0], docs: length}) | sort_by(-.docs) | .[:8]' "$graph")"
      ;;
    skill)
      related="$(jq -c --arg s "$subj_id" '[.edges[] | select(.from == $s and .type == "tagged") | .to] | unique' "$graph")"
      ;;
  esac
  note="the question names $subj_id but no rule matched a relation; returning its whole context (route=bundle). Ask a specific relation for one answer: ops:kg:$(if [ "$subj_type" = "tag" ]; then echo tag; else echo "$subj_type"; fi)"
fi

# --- output ----------------------------------------------------------------
jq -n -c \
  --arg q "$question" \
  --arg intent "$intent" \
  --arg route "$route" \
  --arg graph "$graph" \
  --arg note "$note" \
  --arg subject_route "$subject_route" \
  --argjson conf "$confidence" \
  --argjson decision "$decision" \
  --argjson subject "$subject" \
  --argjson results "$results" \
  --argjson related "$related" \
  --argjson bundle "$bundle" \
  '{
     question: $q,
     intent: $intent,
     route: $route,
     bundle: ($bundle == 1),
     confidence: $conf,
     subject: (if $subject == null then null
               else {id: $subject.id, type: $subject.type, label: $subject.label, via: $subject_route} end),
     results: $results,
     related: $related,
     note: (if $note == "" then null else $note end),
     model: {
       consulted: (($decision.decision // "") != ""),
       name: ($decision.model // "none"),
       suggested: (($decision.decision // "") | split(":")[0]),
       confidence: ($decision.confidence // 0),
       options: ($decision.probabilities // {} | keys | length)
     },
     graph: $graph
   }' >"$out_file"

if [ "$format" = "json" ]; then
  cat "$out_file"
  exit 0
fi

jq -r '
  def row: if type == "object" and .id then
      "  \(.id)"
      + (if .docs then "\t(\(.docs) docs)" elif .skills then "\t(\(.skills) skills)" else "" end)
    elif type == "object" then
      "  " + (to_entries | map("\(.key)=\(.value)") | join(" "))
    else "  \(.)" end;
  "question : \(.question)",
  "intent   : \(.intent) (route: \(.route)\(if .bundle then ", BUNDLE" else "" end), confidence: \(.confidence))",
  (if .subject then "subject  : \(.subject.id) [\(.subject.type)] via \(.subject.via)" else "subject  : (none)" end),
  "model    : \(.model.name) consulted=\(.model.consulted) suggested=\(if .model.suggested == "" then "-" else .model.suggested end) confidence=\(.model.confidence)",
  (if .note then "note     : \(.note)" else empty end),
  "results  :",
  (.results[] | row),
  (if (.related | length) > 0 then "related  :" else empty end),
  (.related[] | row)
' "$out_file" | column -t -s$'\t'
