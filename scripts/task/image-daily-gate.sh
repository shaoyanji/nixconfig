#!/usr/bin/env bash
# image-daily-gate.sh [DIR] — the publish gate: verify the command family is
# structurally able to ship before `publish` rewrites the manifest or a slot
# timer spends the allowance. DIR defaults to this script's own directory and
# exists so a fixture can point the gate at a tree checked out of history —
# a gate that cannot fail on a real past mistake is no gate.
#
# What it checks, and the mistake each check is the memory of:
#   1. dispatch agreement — every token in image-daily.sh's case list has an
#      image-daily-<cmd>.sh and every image-daily-*.sh command file is in the
#      list (lib/engine/gate are not commands). The 2026-11-23 monolith split
#      is only as good as this agreement; a dropped file is a silent `usage:`.
#   2. judge fallback — the provider route (modelProvider + GEMINI_API_KEY
#      + --model) lives in tools/os (the image domain) now, tools/image-daily
#      and image-daily-engine.sh before it; the check accepts any of them so a
#      fixture out of history still gates.
#      Without it the account quota dying is a dead judge: 2026-11-22–23 spent
#      43 generations, kept 0, every verdict "agy exited 3".
#   3. spend circuit breaker — unjudged_streak in the lane loop (Go tool) and
#      in image-daily-plates.sh, so two consecutive unjudged plates stop the
#      lane instead of burning allowance that can never be kept.
#   4. publish shrink guard — cmd_publish calls publish_shrink_guard: on
#      2026-11-21 delphi republished a slice of the bank and the served gallery
#      dropped 556 assets to 144 with every upload intact.
#
# Exit: 0 every check holds, 1 with each failure named on stderr.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-lib.sh
source "$here/image-daily-lib.sh"


cmd_gate() {
  local dir=${1:-$here} fail=0 tok subs files
  [ -f "$dir/image-daily.sh" ] || die "no dispatcher at $dir/image-daily.sh"
  need grep

  # The dispatch contract: the case line is the one list of subcommands; the
  # files on disk are the other. Both directions, because a missing file and a
  # stray file are different mistakes.
  subs=$(grep -oE '^  [a-z|]+\) ;;' "$dir/image-daily.sh" | tr -d ' );' | tr '|' '\n' | grep -v '^$' | sort -u)
  files=$(find "$dir" -maxdepth 1 -name 'image-daily-*.sh' -printf '%f\n' | sed 's/^image-daily-//; s/\.sh$//' | grep -vE '^(lib|engine|gate)$' | sort -u)
  for tok in $subs; do
    [ -f "$dir/image-daily-$tok.sh" ] || { say "gate FAIL: dispatch names '$tok' but image-daily-$tok.sh is missing"; fail=1; }
  done
  for tok in $files; do
    printf '%s\n' "$subs" | grep -qx "$tok" || { say "gate FAIL: image-daily-$tok.sh exists but is not in the dispatch list"; fail=1; }
  done

  # Judge resilience: the account route exhausts for days at a time, so the
  # engine must carry the provider lane or every verdict is unjudged. The check
  # looks at the lib AND the Go tool: the functions moved to tools/os in the
  # one-os-cli fold-in (tools/image-daily before that), and a fixture checked
  # out of history still carries them in either spot — any location holding
  # the contract is the contract held.
  local lib=$dir/image-daily-lib.sh gotool=$dir/../../tools/os legacy=$dir/../../tools/image-daily
  [ -f "$lib" ] || die "no lib at $lib"
  { grep -q 'modelProvider' "$lib" 2>/dev/null && grep -q 'GEMINI_API_KEY' "$lib" 2>/dev/null; } ||
    { grep -rq 'modelProvider' "$gotool" 2>/dev/null && grep -rq 'GEMINI_API_KEY' "$gotool" 2>/dev/null; } ||
    { grep -rq 'modelProvider' "$legacy" 2>/dev/null && grep -rq 'GEMINI_API_KEY' "$legacy" 2>/dev/null; } ||
    { say "gate FAIL: engine has no provider fallback — a dead account route means every plate stays unjudged"; fail=1; }
  grep -q 'unjudged_streak' "$lib" 2>/dev/null || grep -rq 'unjudged_streak' "$gotool" 2>/dev/null ||
    grep -rq 'unjudged_streak' "$legacy" 2>/dev/null ||
    { say "gate FAIL: run_lane has no unjudged circuit breaker — a dead judge burns the whole allowance"; fail=1; }
  # The plates breaker lives wherever the plates loop does: plates.sh on
  # historical trees, tools/os/internal/image/plates.go after the port —
  # grep that file specifically, not the package (run_lane's token there is
  # a different breaker's proof).
  { grep -q 'unjudged_streak' "$dir/image-daily-plates.sh" 2>/dev/null; } ||
    { [ -f "$gotool/internal/image/plates.go" ] && grep -q 'unjudgedStreak' "$gotool/internal/image/plates.go"; } ||
    { say "gate FAIL: plates loop has no unjudged circuit breaker"; fail=1; }

  # Publish safety: the manifest is a union, never a snapshot — the shrink
  # guard must be on the publish path.
  grep -q 'publish_shrink_guard' "$dir/image-daily-publish.sh" 2>/dev/null ||
    { say "gate FAIL: publish has no shrink guard"; fail=1; }

  if [ "$fail" -eq 0 ]; then
    say "gate ok: dispatch, judge fallback, breakers and shrink guard all present"
    return 0
  fi
  return 1
}

cmd_gate "$@"
