#!/usr/bin/env bash
# image-round.sh — the round picker: characters in, plates out, no path typed.
#
# Everything the person would otherwise have to remember is read here: which rows
# the judge has not kept, how much of the day's allowance is left, where the
# roster and the ledger live. The spend is `image-daily.sh plates`, the same entry
# point the nightly slots call, so a round started from this menu and a round
# started by a timer take one path: judge each plate, skip a row already kept,
# publish once, post one xs turn.
#
#   task images:round              # the picker
#   task images:round ONLY=a,b     # no menu, named rows
#
# Exit: 0 a round ran · 2 cancelled, or nothing left to spend.
set -uo pipefail

root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
roster=${ROSTER:-$root/lib/image-daily/plates.txt}
export IMAGES_ROOT=${IMAGES_ROOT:-/Volumes/data/pics/generated}
ledger=$IMAGES_ROOT/ledger.jsonl
daily=$root/scripts/task/image-daily.sh

say() { printf '%s\n' "$*" >&2; }

need_gum() {
  command -v gum >/dev/null || {
    say "gum is not on PATH — nix shell nixpkgs#gum"
    exit 2
  }
  [ -t 0 ] || {
    say "not a terminal: pass ONLY=slug,slug instead of the menu"
    exit 2
  }
}

# The same arithmetic the spend uses, so the header cannot promise what the round
# will refuse: the day's quota minus what it has already spent.
allowance() {
  cpg usage --json 2>/dev/null | jq -r '
    if (.entitlement.limits.imagesPerDay | type) == "number"
    then (.entitlement.limits.imagesPerDay - (.usage.images.used // 0))
    else (.usage.images.remaining // "?") end' 2>/dev/null || printf '?'
}

# Rows with no kept plate, in roster order: what a round can still spend on.
pending_slugs() {
  local all kept
  all=$(mktemp) && kept=$(mktemp) || return 0
  : >"$kept"
  [ -f "$ledger" ] && jq -r 'select(.verdict == "keep") | .brief' "$ledger" 2>/dev/null |
    sed 's/^photoreal-//' | sort -u >"$kept"
  awk -F'|' '!/^#/ && NF > 1 {print $1}' "$roster" | sort -u >"$all"
  comm -23 "$all" "$kept"
  rm -f "$all" "$kept"
}

show_state() {
  local total pending kept assets
  total=$(grep -vc '^#' "$roster")
  pending=$(pending_slugs | grep -c . || true)
  kept=$((total - pending))
  assets=$(wc -l <"$IMAGES_ROOT/published/urls.tsv" 2>/dev/null | tr -d ' ')
  gum style --border rounded --padding "0 1" \
    "roster     $total row(s): $kept kept, $pending waiting" \
    "allowance  $(allowance) image(s) left today" \
    "assets     ${assets:-0} on Cloudinary" \
    "roster     $roster" \
    "ledger     $ledger"
}

run_round() { # only cap
  local only=$1 cap=$2 log rc url kept
  log=$IMAGES_ROOT/.last-round.log
  mkdir -p "$IMAGES_ROOT"
  say "spending ${only:-the roster in order}, at most ${cap:-every} image(s)"
  ONLY="$only" MAX_GEN="$cap" bash "$daily" plates >"$log" 2>&1
  rc=$?
  kept=$(grep -c ': keep$' "$log" 2>/dev/null || true)
  url=$(grep -oE 'https://[a-z0-9]+\.bountystash-assets\.pages\.dev' "$log" | tail -1)
  tail -n 3 "$log" >&2
  gum style --border rounded --padding "0 1" \
    "kept this round  ${kept:-0}" \
    "images spent     $(grep -oE '[0-9]+ image\(s\) spent' "$log" | tail -1 | grep -oE '^[0-9]+' || printf '?')" \
    "live             ${url:-not deployed this pass}" \
    "log              $log"
  return $rc
}

add_custom() {
  local slug prompt expect form="soft feminine facial features, a delicate jawline, a slender neck, a graceful feminine figure"
  slug=$(gum input --header "slug — short, dashes, unique" --placeholder "dota-windranger-alt") || return 2
  [ -n "$slug" ] || return 2
  if grep -qE "^${slug}\|" "$roster"; then
    say "row $slug already exists — use Pick characters"
    return 2
  fi
  prompt=$(gum write --width 90 --height 12 \
    --header "Prompt — who, from where, what they wear, how framed" \
    --placeholder "Name, an adult woman from the game … — hair, eyes, gown and neckline, expression, portrait from the waist up, glamorous and alluring, soft feminine facial features, a delicate jawline, high cheekbones, a slender neck, a graceful feminine figure, 4k, photorealistic, realistic, neumorphism.") || return 2
  prompt=$(printf '%s' "$prompt" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
  [ -n "$prompt" ] || return 2
  # The row is refused without this clause, so a custom character gets it here
  # rather than being typed in by hand every time.
  case $prompt in
  *"soft feminine facial features"*) ;;
  *)
    if printf '%s' "$prompt" | grep -q ', 4k,'; then
      prompt=$(printf '%s' "$prompt" | sed "s/, 4k,/, $form, 4k,/")
    else
      prompt="$prompt, $form"
    fi
    ;;
  esac
  expect=$(gum input --header "Judge expectation — what a literal reading would be" \
    --placeholder "Name as a glamorous lifelike portrait of an adult … , never <icon> alone") || return 2
  printf '%s|%s|%s\n' "$slug" "$prompt" "$expect" >>"$roster"
  say "appended to $roster — commit it when you are happy with the plate"
  printf '%s' "$slug"
}

if [ -n "${ONLY:-}" ]; then
  run_round "$ONLY" "${MAX_GEN:-0}"
  exit $?
fi

need_gum
while true; do
  left=$(allowance)
  pending=$(pending_slugs | grep -c . || true)
  choice=$(gum choose --height 12 \
    --header "Wallpaper round · $left image(s) left today · $pending roster row(s) waiting" \
    "Next rows (roster order)" "Pick characters" "Custom character" "Show state" "Exit") || exit 2
  case $choice in
  "Next rows"*)
    cap=$(gum input --header "How many images at most? (a reroll spends a second)" --value 10) || continue
    [ -n "$cap" ] || cap=0
    gum confirm "Spend up to $cap image(s) on the next unkept rows?" || continue
    run_round "" "$cap"
    ;;
  "Pick characters")
    slugs=$(pending_slugs)
    if [ -z "$slugs" ]; then
      gum style "Every roster row is already kept — add a custom character first."
      continue
    fi
    picked=$(printf '%s\n' "$slugs" | gum choose --no-limit --height 20 --header "Space selects, enter confirms") || continue
    [ -n "$picked" ] || continue
    only=$(printf '%s\n' "$picked" | paste -sd, -)
    count=$(printf '%s\n' "$picked" | grep -c . || true)
    cap=$(gum input --header "How many images at most? (a reroll spends a second)" --value "$count") || continue
    gum confirm "Spend on $count picked row(s), at most $cap image(s)?" || continue
    run_round "$only" "${cap:-0}"
    ;;
  "Custom character")
    slug=$(add_custom) || continue
    cap=$(gum input --header "How many images at most? (a reroll spends a second)" --value 3) || continue
    gum confirm "Render $slug now?" || continue
    run_round "$slug" "${cap:-0}"
    ;;
  "Show state") show_state ;;
  Exit) exit 0 ;;
  esac
done
