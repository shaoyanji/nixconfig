#!/usr/bin/env bash
# One prompt to a second model at the five places a prompt pays: a gate that
# may pass while the thing it guards is broken, a generation prompt about to
# spend image allowance, a plan about to become work, a document that wants a
# schema, and a failure that wants an adversarial reading.
#
# The model has no tools, no repository and no clock, so the packet is the whole
# world it gets. It is capped at 15,000 characters and this refuses over the cap
# instead of cutting the evidence: a truncated diff gets a confident answer
# about the wrong file.
#
#   gate   a diff plus the file it touches; answers what makes the check pass
#          while it is broken, and which line is the vacuous one
#   plate  a generation prompt; answers the defects to look for in the plate
#          before an image is spent, plus the one edit likely to remove the worst
#   plan   a document; answers the objections, ordered by what being wrong costs
#   schema    a document; answers a schema for it, in a fixed YAML shape
#   adversary a failure or checkpoint plus the code that asserts it; answers a
#             verdict in a fixed YAML shape: the other readings, what was taken
#             on trust, and the one probe that settles it
#   draft     a skeleton document plus the material; answers the skeleton filled
#             in, and the caller's key set is enforced. This is the direction a
#             tool-calling harness needs: hermes owns the tools and the loop, a
#             cheap model here owns the drafting, and the validated YAML is the
#             artifact that crosses between them — data, not prose to re-parse.
#
# `schema` and `adversary` ask for YAML and are held to it: the reply goes through
# llm-yaml.sh (fence, backtick and prose removal) and then a yq shape check, and a
# reply that does not parse exits 1. A chatty answer is a failed call, not a
# paraphrase -- once the shape is machine-checked, "it looked right" is not a
# result. This is the shape to reach for whenever the question is logic and the
# answer should be data: a schema to postulate, an opinion to file.
#
# Usage:
#   cpg-review.sh gate  [--diff PATH] [--file PATH] [--dry-run] [--json]
#   cpg-review.sh plate [--size 1536x1024] [--intent TEXT]
#                       [--prompt TEXT | --prompt-file PATH] [--dry-run] [--json]
#   cpg-review.sh plan  [--prompt-file PATH] [--dry-run] [--json]
#   cpg-review.sh schema    [--prompt-file PATH] [--out PATH] [--dry-run] [--json]
#   cpg-review.sh adversary [--diff PATH] [--file PATH] [--out PATH]
#                           [--dry-run] [--json]
#   cpg-review.sh draft --shape PATH [--prompt-file PATH] [--out PATH]
#                         [--dry-run] [--json]
#
# The material is read from --prompt/--prompt-file, else stdin. `gate` defaults to
# `git diff HEAD`, and `--file` adds the whole check so the reviewer sees the
# assertion and its surroundings rather than a hunk with no context.
#
# Env: MODEL (default claude-haiku-5-5), FALLBACK (default gpt-6-luna, one
#      retry when the first takes too long), SESSION, MAX (packet characters,
#      default 15000). The premium ids — claude-sonnet-5-5, gpt-6.1-sol — answer
#      403 MODEL_NOT_ALLOWED on this lifetime pool; `cpg models --json` marks
#      them premium_only, so a named default has to be checked, not assumed.
# Exit: 0 answered · 1 the call failed · 2 usage, empty packet, or over the cap
set -euo pipefail

MAX="${MAX:-15000}"
MODEL="${MODEL:-claude-haiku-5-5}"
# "The model took too long to respond" is a busy endpoint, not a review, and it
# spends no prompt, so one retry on a second vendor is free and a second failure
# is the answer.
FALLBACK="${FALLBACK:-gpt-6-luna}"
SESSION="${SESSION:-}"

die() {
  printf 'cpg-review: %s\n' "$*" >&2
  exit 2
}

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
}

mode="${1:-}"
case "$mode" in
  -h | --help)
    usage
    exit 0
    ;;
  '')
    die "mode required: gate | plate | plan | schema | adversary | draft"
    ;;
esac
shift || true

diff_path="" file_path="" size="1536x1024" intent="a desktop wallpaper"
prompt="" prompt_file="" out_path="" shape_path="" dry=0 json=0

while [ $# -gt 0 ]; do
  case "$1" in
    --diff)
      diff_path="${2:?--diff needs a path}"
      shift 2
      ;;
    --file)
      file_path="${2:?--file needs a path}"
      shift 2
      ;;
    --size)
      size="${2:?--size needs WxH}"
      shift 2
      ;;
    --intent)
      intent="${2:?--intent needs text}"
      shift 2
      ;;
    --prompt)
      prompt="${2:?--prompt needs text}"
      shift 2
      ;;
    --prompt-file)
      prompt_file="${2:?--prompt-file needs a path}"
      shift 2
      ;;
    --out)
      out_path="${2:?--out needs a path}"
      shift 2
      ;;
    --shape)
      shape_path="${2:?--shape needs a path}"
      shift 2
      ;;
    --dry-run)
      dry=1
      shift
      ;;
    --json)
      json=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

read_text() { # path
  [ -f "$1" ] || die "no such file: $1"
  cat -- "$1"
}

cd "$(git rev-parse --show-toplevel)"

# The prompt argument is the material for plate and plan; gate builds its own.
if [ -z "$prompt" ] && [ -n "$prompt_file" ]; then
  prompt=$(read_text "$prompt_file")
fi
if [ -z "$prompt" ] && [ "$mode" != gate ] && [ ! -t 0 ]; then
  prompt=$(cat)
fi

packet=""
case "$mode" in
  gate)
    if [ -n "$diff_path" ]; then
      diff_text=$(read_text "$diff_path")
    else
      diff_text=$(git diff HEAD -- 2>/dev/null || true)
      [ -n "$diff_text" ] || diff_text=$(git show --format= --patch HEAD 2>/dev/null || true)
    fi
    [ -n "$diff_text" ] || die "empty diff — stage the change or pass --diff PATH"
    packet="DIFF UNDER REVIEW:
$diff_text"
    if [ -n "$file_path" ]; then
      packet="$packet

FILE UNDER REVIEW ($file_path):
$(read_text "$file_path")"
    fi
    packet="You are reviewing a check, not the code it guards. This repository's
gates are scripts and assertions that must fail when the thing they guard
breaks. Find how this one passes while it is broken.

Answer in at most six bullets, no preamble, no praise:
- one bullet per input or state that makes it pass vacuously: a value, a file, an
  exit status, a missing command — not \"consider edge cases\"
- then the single most likely vacuous pass: name the line and say why in one
  sentence
- then one input that would make it fail for the wrong reason
If the check cannot fail at all, say so in one sentence first.

$packet"
    ;;
  plate)
    [ -n "$prompt" ] || die "plate needs a generation prompt (--prompt, --prompt-file, or stdin)"
    packet="A single image generation is about to be spent from a daily allowance.
Read the generation prompt below and list only the defects that would make the
plate worthless: what the image model adds unasked or gets wrong.

INTENT: $intent
SIZE: $size

GENERATION PROMPT:
$prompt

Answer in at most five bullets, each one thing to check in the returned file
(composition, subject count and identity, lettering, borders, aspect, style
drift), most likely first. Then one line: the single edit to the prompt most
likely to remove the top defect. No preamble."
    ;;
  plan)
    [ -n "$prompt" ] || die "plan needs the document (--prompt-file or stdin)"
    packet="Adversarial read of a plan that is about to become work. You cannot
check its facts; judge its structure: what it assumes, what it leaves out, and
what breaks first when it runs.

PLAN:
$prompt

Answer in at most six bullets, ordered by what being wrong costs, each one
objection with its consequence. Then one line: the cheapest test that would
settle the top objection. No restatement, no praise."
    ;;
  schema)
    [ -n "$prompt" ] || die "schema needs the document (--prompt-file or stdin)"
    packet="A document is about to be described by a schema. Propose the schema it
must satisfy, not a copy of it: the keys that have to be there, the types, the
enums the sample demonstrates, and the constraints a second file would have to
meet to be one of these.

Return ONLY YAML. No fence, no prose, no commentary before or after, and no key
outside this shape:

doc: <one line: what this document is>
fields:
  - path: <dotted path into the document>
    type: <string|int|number|bool|list|map|enum>
    required: <true|false>
    evidence: <the value or count in the sample that implies it>
    constraints: [<short machine-checkable rules; [] if none>]
open_questions:
  - <a choice the sample cannot settle, and the two answers>

Every field must cite the sample. Anything the sample cannot settle goes in
open_questions, never into a guess written like a requirement.

DOCUMENT:
$prompt"
    ;;
  adversary)
    [ -n "$prompt" ] || die "adversary needs the failure or checkpoint text (--prompt, --prompt-file or stdin)"
    packet="A check failed, or a checkpoint is about to be crossed, and the person
reading it is tired. You cannot look anything up: judge the logic, not the facts,
and say plainly which claims you are taking on trust.

FAILURE OR CHECKPOINT:
$prompt"
    if [ -n "$file_path" ]; then
      packet="$packet

CODE THAT ASSERTS IT ($file_path):
$(read_text "$file_path")"
    fi
    if [ -n "$diff_path" ]; then
      packet="$packet

CHANGE UNDER SUSPICION:
$(read_text "$diff_path")"
    fi
    packet="$packet

Return ONLY YAML, no fence and no prose, in exactly this shape:

verdict: <pass|fail|ambiguous>
because: <one sentence: what the evidence actually establishes>
could_mean: [<the other readings of this failure, one line each>]
trusted: [<claims this rests on that you did not verify>]
next_probe: <the single command or reading that would settle it>
weak_spots: [<where this reading is most likely wrong>]

Order could_mean by what being wrong about that reading would cost."
    ;;
  draft)
    [ -n "$shape_path" ] || die "draft needs --shape PATH (a skeleton document with the keys you want back)"
    [ -n "$prompt" ] || die "draft needs the material (--prompt, --prompt-file or stdin)"
    packet="A caller needs a structured artifact as YAML, not prose. Fill in the
skeleton below with real content: the same keys, the same nesting, nothing added
and nothing dropped. A placeholder left in the answer is a failure, and so is a
key the skeleton does not have.

REQUEST AND MATERIAL:
$prompt

SKELETON (keys and nesting are the contract; replace the values):
$(read_text "$shape_path")

Return ONLY YAML, no fence and no prose. Every skeleton key present, no extra
key, lists as lists, booleans as true/false."
    ;;
  *)
    die "unknown mode: $mode (gate | plate | plan | schema | adversary | draft)"
    ;;
esac

chars=$(printf '%s' "$packet" | wc -c | tr -d ' ')
[ "$chars" -gt 0 ] || die "empty packet"
if [ "$chars" -gt "$MAX" ]; then
  die "packet is $chars characters, $((chars - MAX)) over the $MAX cap — cut the material down, do not truncate it here"
fi

if [ "$dry" -eq 1 ]; then
  printf '%s\n' "$packet"
  printf 'cpg-review: dry run, mode=%s model=%s chars=%s, nothing sent\n' "$mode" "$MODEL" "$chars" >&2
  exit 0
fi

[ -n "$SESSION" ] || SESSION="review-$mode-$(date -u +%Y%m%dT%H%M%SZ)"

# The reply is text on stdout when it is not a TTY, but a failed call mixes the
# error in with it, so both are captured and the ANSI is taken out either way.
strip() { sed -e $'s/\x1b\\[[0-9;?]*[a-zA-Z]//g' -e 's/\r//g'; }

# One answered call moved `dailyQueries.used` by 7 on 2026-11-11, so the plan's
# 350 queries is about 50 calls, not 350. The delta is measured around the call
# and reported: a lane that hides its own cost is how a 50-a-day budget gets
# planned like a 350-a-day one.
usage_pair() {
  cpg usage --json 2>/dev/null |
    jq -r '[.usage.dailyQueries.used, .usage.dailyQueries.remaining] | @tsv' 2>/dev/null || true
}

used_before=""
used_after=""
if [ "$dry" -eq 0 ]; then
  used_before=$(usage_pair || true)
fi

models=("$MODEL")
if [ -n "$FALLBACK" ] && [ "$FALLBACK" != "$MODEL" ]; then
  models+=("$FALLBACK")
fi

clean="" answered="" last_error=""
for model in "${models[@]}"; do
  if [ -n "$clean" ]; then
    break
  fi
  raw="" rc=0
  raw=$(cpg chat -m "$model" -s "$SESSION" "$packet" 2>&1) || rc=$?
  reply=$(printf '%s' "$raw" | strip)
  if [ "$rc" -ne 0 ] || [ -z "$(printf '%s' "$reply" | tr -d '[:space:]')" ]; then
    last_error="$reply (exit $rc)"
    continue
  fi
  clean="$reply"
  answered="$model"
done

if [ -z "$clean" ]; then
  printf 'cpg-review: no answer from %s\n' "${models[*]}" >&2
  printf '%s\n' "$last_error" | tail -5 >&2
  case "$last_error" in
    *authenticated* | *"Sign in to continue"*)
      printf 'cpg-review: session is dead — run `cpg refresh`, then retry once\n' >&2
      ;;
    *premium_only* | *MODEL_NOT_ALLOWED*)
      printf 'cpg-review: that id is premium on this plan — pick a basic one from `cpg models --json`\n' >&2
      ;;
  esac
  exit 1
fi

if [ "$answered" != "$MODEL" ]; then
  printf 'cpg-review: %s did not answer, %s did\n' "$MODEL" "$answered" >&2
fi

spent=""
remaining_now=""
if [ -n "$used_before" ]; then
  used_after=$(usage_pair || true)
fi
if [ -n "$used_before" ] && [ -n "$used_after" ]; then
  # usage_pair prints "used<TAB>remaining"; the delta is the first field of each
  spent=$(( ${used_after%%$'\t'*} - ${used_before%%$'\t'*} ))
  remaining_now="${used_after##*$'\t'}"
  printf 'cpg-review: spent %s queries, %s left today (one call is about 7, so ~50 a day)\n' \
    "$spent" "$remaining_now" >&2
fi

case "$mode" in
  schema | adversary | draft)
    # The shape is the contract. A reply that does not parse is a failed call,
    # and the raw text is printed so the cause is visible rather than guessed.
    yaml_rc=0
    cleaned=$(printf '%s\n' "$clean" | bash "$(dirname "$0")/llm-yaml.sh" --map) || yaml_rc=$?
    if [ "$yaml_rc" -ne 0 ]; then
      printf 'cpg-review: %s did not return parseable YAML\n' "$answered" >&2
      printf '%s\n' "$clean" | tail -12 >&2
      exit 1
    fi
    case "$mode" in
      schema)
        if ! yq -e '(.fields | type) == "!!seq" and (.fields | length) > 0 and (.open_questions | type) == "!!seq"' >/dev/null 2>&1 <<<"$cleaned"; then
          printf 'cpg-review: %s answered YAML, but not the schema shape (fields[] non-empty, open_questions[])\n' "$answered" >&2
          printf '%s\n' "$cleaned" | head -20 >&2
          exit 1
        fi
        ;;
      adversary)
        if ! yq -e '(.verdict | type) == "!!str" and (.because | type) == "!!str" and (.next_probe | type) == "!!str"' >/dev/null 2>&1 <<<"$cleaned"; then
          printf 'cpg-review: %s answered YAML, but not the verdict shape (verdict, because, next_probe)\n' "$answered" >&2
          printf '%s\n' "$cleaned" | head -20 >&2
          exit 1
        fi
        ;;
      draft)
        # The caller's skeleton is the schema: the same top-level keys back, or
        # the artifact is not something a harness can consume by name.
        want=$(yq -r 'keys | .[]' <<<"$(read_text "$shape_path")" 2>/dev/null | sort)
        got=$(yq -r 'keys | .[]' <<<"$cleaned" 2>/dev/null | sort)
        if [ "$want" != "$got" ]; then
          printf 'cpg-review: %s answered YAML with keys that do not match %s\n' "$answered" "$shape_path" >&2
          printf '  missing: %s\n' "$(comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | tr '\n' ' ')" >&2
          printf '  extra:   %s\n' "$(comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | tr '\n' ' ')" >&2
          printf '%s\n' "$cleaned" | head -20 >&2
          exit 1
        fi
        ;;
    esac
    clean="$cleaned"
    if [ -n "$out_path" ]; then
      printf '%s\n' "$clean" >"$out_path"
      printf 'cpg-review: wrote %s from %s\n' "$out_path" "$answered" >&2
    fi
    ;;
esac

if [ "$json" -eq 1 ]; then
  jq -n --arg mode "$mode" --arg asked "$MODEL" --arg model "$answered" \
    --arg session "$SESSION" --argjson chars "$chars" --arg reply "$clean" \
    --argjson spent "${spent:-null}" --argjson left "${remaining_now:-null}" \
    '{mode: $mode, requested_model: $asked, model: $model, session: $session, prompt_chars: $chars, queries_spent: $spent, queries_left: $left, reply: $reply}'
else
  printf '%s\n' "$clean"
fi
