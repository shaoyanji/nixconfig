#!/usr/bin/env bash
# image-daily-approve.sh — a day's kept plates into the wallpaper rotation, newest first
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-engine.sh
source "$here/image-daily-engine.sh"





# The judgement is the keep; approval is what makes a kept plate a wallpaper, and
# the first id in `wall.in` is the one `wallpaper` installs. A round approves its
# own keeps, newest first, so the rotation follows the roster without a second
# command. Idempotent: an id already listed is skipped, an id rejected in
# `wall.out` stays rejected (a rejection wins over an approval), and an id whose
# file is not on disk is skipped rather than added to fail later at install time.

cmd_approve() {
  local rotation=$repo/lib/image-daily/rotation.json day=${DAY:-$(today)} tmp id added
  local -a ids=() new=()
  [ -f "$rotation" ] || die "no rotation at $rotation"
  [ -f "$LEDGER" ] || { say "approve: no ledger yet"; return 0; }
  # The ledger stores the absolute path; a rotation id is the part under the lane
  # root, and published/ wins over src/ when both exist (`resolve_plate`'s rule).
  mapfile -t ids < <(
    jq -r --arg d "$day" 'select(type == "object") | select(.day == $d and .verdict == "keep") | .path' "$LEDGER" |
      while IFS= read -r p; do
        id=${p#*/published/wall/}
        [ "$id" = "$p" ] && id=${p#*/src/wall/}
        printf '%s\n' "$id"
      done | tac | awk '!seen[$0]++'
  )
  for id in "${ids[@]}"; do
    [ -n "$id" ] || continue
    case $id in /* | *"$IMAGES_ROOT"*) continue ;; esac
    jq -e --arg id "$id" 'any((.wall.in // [])[]; . == $id)' "$rotation" >/dev/null 2>&1 && continue
    jq -e --arg id "$id" '(.wall.out // {}) | has($id)' "$rotation" >/dev/null 2>&1 && continue
    [ -f "$IMAGES_ROOT/published/wall/$id" ] || [ -f "$IMAGES_ROOT/src/wall/$id" ] || continue
    new+=("$id")
  done
  [ "${#new[@]}" -gt 0 ] || { say "approve: nothing new for $day"; return 0; }
  if [ "${DRY:-0}" = "1" ]; then printf '%s\n' "${new[@]}"; return 0; fi
  added=$(printf '%s\n' "${new[@]}" | jq -R . | jq -sc .) || die "approve: could not encode the list"
  tmp=$(mktemp) || die "approve: no temp file"
  jq --argjson add "$added" '.wall.in = ($add + (.wall.in // []))' "$rotation" >"$tmp" &&
    mv "$tmp" "$rotation" || { rm -f "$tmp"; die "approve: could not write $rotation"; }
  say "approved ${#new[@]} plate(s) for $day, newest first"
}

cmd_approve "$@"
