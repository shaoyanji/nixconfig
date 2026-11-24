#!/usr/bin/env bash
# image-daily.sh — dispatch for the image-daily command family:
#
#   image-daily.sh <cmd> runs scripts/task/image-daily-<cmd>.sh — one file per
#   command, the shared vocabulary in image-daily-lib.sh; the generation and
#   publish machinery is the Go CLI (tools/image-daily, .#cli.image.daily),
#   reached through `image_daily_cli`. The dispatch contract is unchanged, so
#   the slot timers, sibling scripts and the taskfile keep working untouched.
#
# WHY THIS EXISTS: the allowance is 100 images per day and it does not carry
# over, so a day nobody spends is a day thrown away — and a queue kept in a
# person's head rots the first week they are busy. The queue is a file with a
# `every` per brief (`lib/image-daily/briefs.json`): a brief is due when its
# lane's last accepted asset for that id is older than that, so the runner
# refreshes itself without anybody editing a rota.
#
# The rules that keep it unattended:
#   1. Nothing is kept that a judge has not passed. agy reads the PNG and
#      answers the schema; a judge that cannot answer leaves the plate
#      `unjudged` — kept on disk, never published. Never blind-accept.
#   2. Every generation attempt lands in the ledger (`ledger.jsonl`) with the
#      prompt that produced it, so `status` can say a lane is stale without
#      trusting a timer's green light and the re-roll rate is readable later.
#   3. A brief that spends three images without a keep is parked for a week, so
#      a prompt the judge keeps refusing costs a few plates, not every slot.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
sub=${1:-plan}
case "$sub" in
  plan|run|status|today|share|judge|publish|variants|post|gc|blog|wallpaper|plates|round|adopt|add|approve|remaining|gate) ;;
  *) echo "usage: image-daily.sh plan|run|status|today|share SLOTS_LEFT|judge PATH|publish|adopt|add FILE [URL]|post|gc|blog [--dir PATH]|variants|wallpaper|plates|round [status]|approve|remaining|gate [DIR]" >&2; exit 1 ;;
esac
shift || true
exec "$here/image-daily-$sub.sh" "$@"
