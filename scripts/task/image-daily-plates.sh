#!/usr/bin/env bash
# image-daily-plates.sh — a requested round of photoreal character plates from the roster
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-engine.sh
source "$here/image-daily-engine.sh"


# A requested character plate is not a brief and cannot be one: a brief is a
# freshness promise (`every`), and nobody wants the same person redrawn on a
# schedule. It also cannot ride the wall lane, whose intent is illustrated art —
# a photographic plate is refused by that intent at judging time, which is how the
# 2026-11-12 burst lost plates it had already paid for. So the round has its own
# intent (`.intents.photoreal`), its own roster, and one property that makes it the
# go-to spend: a row whose plate the judge kept is skipped, so re-running the
# round renders nothing twice and a half-finished round resumes for free.
#
# Roster lines are `<slug>|<prompt>|<expect>`; `|` is not otherwise used in a
# prompt, and `expect` is what lets the judge call a literal reading of a name a
# reroll. The tail `4k, photorealistic, realistic, neumorphism.` is the family the
# 2026-11-10 palette test settled on, so it lives in each line rather than here.

kept_plate() { # brief
  [ -f "$LEDGER" ] || return 0
  # `type == "object"` first: the ledger is append-only and read while a round is
  # still writing it, so a half-written line fails the whole query and reads as
  # "no kept plate" for every row. One torn read did exactly that on 2026-11-16.
  jq -r --arg b "$1" 'select(type == "object") | select(.brief == $b and .verdict == "keep") | .path' "$LEDGER" |
    tac | while IFS= read -r p; do
      [ -f "$p" ] && { printf '%s\n' "$p"; break; }
    done
  # An empty pipeline exits 1, and under `set -e` that killed the whole round the
  # first time a kept plate's file was not on disk (2026-11-16, five parked plates).
  # "no kept plate" is an answer, not an error.
  return 0
}


# A row the judge refuses outright, or refuses again after its one correction,
# is parked — `hold: <reason> :: ` on the prompt field is the skip the round
# reads at the top of the loop, and the reason is sanitized to stay one field.
# Re-casting rewrites the row and drops the prefix by hand; the engine never
# releases a hold on its own.

hold_roster_row() { # roster slug reason
  local roster=$1 slug=$2 reason
  reason=$(printf '%s' "$3" | tr '|\t' '  ' | tr '\n' ' ' | tr -s ' ' | cut -c1-140)
  [ -n "$reason" ] || reason="judge refused it"
  awk -v s="$slug" -v r="$reason" -F'|' 'BEGIN{OFS="|"} $1==s && $2 !~ /^hold:/ {$2 = "hold: " r " :: " $2} {print}' \
    "$roster" >"$roster.hold.$$" && mv "$roster.hold.$$" "$roster"
}


# A row that names only garments and coverage is drawn as a broad, heavy-jawed
# figure: the 2026-11-16 seraph round came back looking like men in armour. The
# fix is a face clause on the row, not a stronger adjective in the judge, and the
# clause stays in `plates.txt` because a plate's prompt is the whole instruction.
# This is the engine refusing to spend on a row that forgot it.
PLATE_FORM="soft feminine facial features"

# Some faces only come out of an archetype: the adjective list was reached for on
# 2026-11-16 and returned a heavy jaw in a slim gown, so a row may name a type
# instead — `arch:sultry-siren` rather than re-deriving a face from hair and a
# gown. The traits live in one file, are substituted in before the row is sent and
# before the guard below runs, so the expanded sentence is what the ledger records
# and a row naming an archetype still cannot skip the clause. An unknown name
# refuses the row; it never falls back to a bare word.
PLATE_ARCH_FILE=${PLATE_ARCH_FILE:-$repo/lib/image-daily/archetypes.tsv}

# Two families of row were the ones that kept failing: a villain came back a gaunt
# mask, a knight came back a bulky torso. Naming the face by archetype is now a
# requirement in those families rather than advice, so a new villain or armour row
# cannot re-describe the face that failed. A kept plate never reaches this check.
PLATE_ARCH_REQUIRED='armour|armored|armoured|pauldron|breastplate|knight|knightess|valkyrie|villain|villainess|witch|sorceress|empress|huntress|assassin|swordswoman|nemesis'

# Every row on this roster is an adult woman. A male character has no place on it:
# `duncan-idaho` was on the roster until 2026-11-16 and spent an image drawing a
# man as a woman, which is wrong however well the plate is made. The judge cannot
# know canon, so the row itself is refused before any allowance is touched.
PLATE_MALE='(^|[^a-z])(an adult man|adult male|a man|male character|the man|he is|his face|his hair|his eyes|his jaw)([^a-z]|$)'

plate_expand() { # prompt -> prompt with every arch:<name> resolved
  local p=$1 name traits
  case $p in *arch:*) ;; *) printf '%s' "$p"; return 0 ;; esac
  [ -f "$PLATE_ARCH_FILE" ] || { say "no archetype file at $PLATE_ARCH_FILE"; return 1; }
  for name in $(printf '%s' "$p" | grep -o 'arch:[a-z0-9-]*' | sed 's/^arch://' | sort -u); do
    traits=$(awk -F'|' -v n="$name" '!/^#/ && $1 == n {print $2; exit}' "$PLATE_ARCH_FILE")
    if [ -z "$traits" ]; then
      say "arch:$name is not in $PLATE_ARCH_FILE — known: $(awk -F'|' '!/^#/ && NF > 1 {printf "%s ", $1}' "$PLATE_ARCH_FILE")"
      return 1
    fi
    p=${p//arch:$name/$traits}
  done
  printf '%s' "$p"
}


cmd_plates() {
  need jq cpg agy git ffprobe
  local roster=${ROSTER:-$repo/lib/image-daily/plates.txt} def_size=${SIZE:-1536x1024}
  [ -f "$roster" ] || die "no roster at $roster"
  if [ "${DETACH:-0}" = "1" ]; then
    "$(image_daily_cli)" round --roster "$roster"
    return 0
  fi
  local intent cli
  cli=$(image_daily_cli)
  intent=$(jq -r '.intents.photoreal // empty' "$BRIEFS")
  [ -n "$intent" ] || die "briefs.json carries no .intents.photoreal"
  # A requested round is allowed to wait the burst window out: the alternative is
  # spending five plates, then abandoning the round when the hourly bucket closes
  # (measured 2026-11-17: 5 spent, 18 rows left waiting). The budget is one window,
  # not the nightly lane's 420 s, because the bucket refills over an hour; the round
  # still ends on the first row that spends it, since every later row would be
  # probing the same closed bucket.
  export RATE_TRIES=${RATE_TRIES:-8} RATE_WAIT=${RATE_WAIT:-300} RATE_WAIT_MAX=${RATE_WAIT_MAX:-900}
  export RATE_WAIT_TOTAL=${RATE_WAIT_TOTAL:-3600}
  mkdir -p "$IMAGES_ROOT" "$STAGE"
  exec 9>"$IMAGES_ROOT/.run.lock"
  flock -n 9 || { say "another run holds the lock"; exit 0; }

  local day spent=0 left cap=${MAX_GEN:-0} slug prompt expect row_size size have file v verdict defect sent rc=0 hold_reason retried unjudged_streak=0
  local holds_file
  holds_file=$(mktemp)
  local ledger_before=0
  [ -f "$LEDGER" ] && ledger_before=$(wc -l <"$LEDGER" | tr -d ' ')
  day=$(today)
  left=$(remaining)
  [ -n "$left" ] || die "usage unreadable (401 from cpg) — run cpg refresh, or chatplayground-go login when the session itself is gone"
  say "plates: $(grep -vc '^#' "$roster") row(s) in the roster, $left image(s) left${cap:+, cap $cap}"

  # A fourth field is that row's own size. The default is a landscape plate, and
  # a phone wallpaper is 1024x1536: asking for the default crops it silently, and
  # `attempt` then discards the answer for being the size it was not asked for.
  # An empty field means the roster default, so every existing row is unchanged.
  while IFS='|' read -r slug prompt expect row_size; do
    [ -n "$slug" ] || continue
    case $slug in \#*) continue ;; esac
    if [ -n "$row_size" ] && ! printf '%s' "$row_size" | grep -qE '^[0-9]+x[0-9]+$'; then
      say "$slug: size '$row_size' is not WxH — row skipped"
      continue
    fi
    size=${row_size:-$def_size}
    # A row the provider refuses is held, not deleted: the reason travels on the
    # row so a round says why it skipped it instead of recording the same refusal
    # again. Measured 2026-11-16: seven live-action and comic characters answered
    # VALIDATION_FAILED about their identity, and softening the sentence and
    # changing the archetype changed nothing. Re-casting means rewriting the row
    # and dropping the prefix; the engine never releases a hold on its own.
    case $prompt in
    hold:*)
      hold_reason=${prompt#hold: }
      hold_reason=${hold_reason%% ::*}
      say "$slug: held — $hold_reason"
      continue
      ;;
    esac
    # An empty ONLY is not a filter that matches nothing: it is no filter at all.
    if [ -n "${ONLY:-}" ]; then
      case ",$ONLY," in *",$slug,"*) ;; *) continue ;; esac
    fi
    if [ "${FORCE:-0}" != "1" ]; then
      have=$(kept_plate "photoreal-$slug")
      [ -n "$have" ] && { say "$slug: kept already ($have)"; continue; }
    fi
    if printf '%s' "$prompt" | grep -qiE "$PLATE_MALE"; then
      say "$slug: row describes a man — this roster is adult women only (duncan-idaho was removed after it rendered a man as a woman)"
      continue
    fi
    if ! printf '%s' "$prompt" | grep -qi 'arch:' &&
      printf '%s' "$prompt" | grep -qiE "$PLATE_ARCH_REQUIRED"; then
      say "$slug: villain or armour row without an archetype — name one of: $(awk -F'|' '!/^#/ && NF > 1 {printf "%s ", $1}' "$PLATE_ARCH_FILE")"
      continue
    fi
    prompt=$(plate_expand "$prompt") || continue
    case $prompt in
    *"$PLATE_FORM"*) ;;
    *) say "$slug: no form clause — add '$PLATE_FORM, a delicate jawline, a slender neck, a graceful feminine figure' or an arch:<name> from $PLATE_ARCH_FILE to the row"
       continue ;;
    esac
    [ "$left" -gt 0 ] || { say "allowance spent"; break; }
    if [ "$cap" -gt 0 ] && [ "$spent" -ge "$cap" ]; then
      say "cap $cap reached; the rest of the roster waits for the next round"
      break
    fi
    if [ "${DRY:-0}" = "1" ]; then
      say "would generate $slug ($size) -> wall/$day/$slug.png"
      spent=$((spent + 1))
      continue
    fi

    retried=0
    file=$("$cli" attempt --id "photoreal-$slug" --lane wall --size "$size" --name "$slug.png" --prompt "$prompt" --day "$day" --n 1 --rev 1) || {
      rc=$?
      [ "$rc" -eq 2 ] && { say "burst window closed; the rest of the roster waits for the next round"; break; }
      [ "$rc" -eq 3 ] && { say "allowance spent; the rest of the roster waits for the next slot"; break; }
      continue
    }
    left=$((left - 1))
    v=$("$cli" judge --png "$file" --lane wall --intent "$intent" --expect "$expect")
    verdict=$(printf '%s' "$v" | jq -r '.verdict')
    defect=$(printf '%s' "$v" | jq -r '.defect // ""')
    spent=$((spent + 1))
    record "$day" wall "photoreal-$slug" "$file" "$verdict" "$("$cli" reason --json "$v")" "$prompt" 1 1

    if [ "$verdict" = "reroll" ] && [ -n "$defect" ] && [ "$left" -gt 0 ] &&
      { [ "$cap" -eq 0 ] || [ "$spent" -lt "$cap" ]; }; then
      say "$slug: reroll — $defect"
      rm -f "$file"
      sent="$prompt (Change only this: $defect.)"
      file=$("$cli" attempt --id "photoreal-$slug" --lane wall --size "$size" --name "$slug.png" --prompt "$sent" --day "$day" --n 2 --rev 1) || {
        rc=$?
        [ "$rc" -eq 2 ] && { say "burst window closed; the rest of the roster waits for the next round"; break; }
        [ "$rc" -eq 3 ] && { say "allowance spent; the rest of the roster waits for the next slot"; break; }
        continue
      }
      left=$((left - 1))
      v=$("$cli" judge --png "$file" --lane wall --intent "$intent" --expect "$expect")
      verdict=$(printf '%s' "$v" | jq -r '.verdict')
      defect=$(printf '%s' "$v" | jq -r '.defect // ""')
      spent=$((spent + 1))
      retried=1
      record "$day" wall "photoreal-$slug" "$file" "$verdict" "$("$cli" reason --json "$v")" "$sent" 2 1
    fi
    say "$slug: $verdict"
    # Two unjudged plates in a row is a dead judge, not a bad image: every
    # plate past this point spends a generation that can never be kept.
    if [ "$verdict" = unjudged ]; then
      unjudged_streak=$((unjudged_streak + 1))
      if [ "$unjudged_streak" -ge 2 ]; then
        say "judge unreachable twice — the round stops before more allowance burns unjudged"
        break
      fi
    else
      unjudged_streak=0
    fi
    # A refused row is parked, not re-rolled forever: `fail` is terminal on the
    # first look, `reroll` after its correction (or with no defect to correct)
    # is spent too. `unjudged` is NOT held — it is agy being down or out of
    # quota, and parking the whole roster for a judge outage is the worse bug.
    case $verdict in
    fail) printf '%s\t%s\n' "$slug" "$("$cli" reason --json "$v")" >>"$holds_file" ;;
    reroll) { [ "$retried" -eq 1 ] || [ -z "$defect" ]; } &&
      printf '%s\t%s\n' "$slug" "$("$cli" reason --json "$v")" >>"$holds_file" ;;
    esac
  done <"$roster"
  if [ -s "$holds_file" ]; then
    while IFS=$'\t' read -r slug hold_reason; do
      hold_roster_row "$roster" "$slug" "$hold_reason" && say "$slug: held — $hold_reason"
    done <"$holds_file"
  fi
  rm -f "$holds_file"

  say "$day: $spent image(s) spent this round"
  if [ "${PUBLISH:-1}" = "1" ] && [ "${DRY:-0}" != "1" ] && [ "$spent" -gt 0 ]; then
    cmd_publish || say "publish failed; the plates are on disk and the next publish picks them up"
  fi
  # The judgement is already made, so approval is the only step between a keep and
  # a wallpaper; a round does it for its own plates. APPROVE=0 leaves the rotation
  # to the operator.
  if [ "${APPROVE:-1}" = "1" ] && [ "${DRY:-0}" != "1" ] && [ "$spent" -gt 0 ]; then
    cmd_approve || say "approve failed; the plates are on disk and `images:approve` retries it"
  fi

  # The round reports itself. It runs from a timer with nobody reading the log, and
  # xs-notify toasts a turn on the machine the person is actually at, so the result
  # travels instead of the person watching for it. Never fatal: the plates are on
  # disk and the ledger already holds the verdicts, so a failed post costs a toast,
  # not a round.
  if [ "${DRY:-0}" != "1" ] && [ "${XS_SUMMARY:-1}" = "1" ]; then
    local round_keeps pending assets outcome line
    round_keeps=$(tail -n +"$((ledger_before + 1))" "$LEDGER" 2>/dev/null |
      jq -r 'select(type == "object") | select((.brief // "") | startswith("photoreal-")) | select(.verdict == "keep") | .brief' 2>/dev/null |
      wc -l | tr -d ' ')
    pending=$("$(image_daily_cli)" pending --roster "$roster")
    assets=$(wc -l <"$IMAGES_ROOT/published/urls.tsv" 2>/dev/null | tr -d ' ')
    outcome=in_progress
    [ "${round_keeps:-0}" -gt 0 ] && outcome=done
    line="$day: ${round_keeps:-0} plate(s) kept of $spent spent, ${pending:-?} roster row(s) waiting, ${assets:-0} asset(s) published"
    say "summary: $line"
    SUBJECT=nixconfig:wall-plates ACTION="$line" OUTCOME=$outcome SOURCE=image-daily \
      bash "$repo/scripts/task/xs-turn-post.sh" >/dev/null 2>&1 ||
      say "xs turn not posted; the next post replays the queue"
  fi
}

cmd_plates "$@"
