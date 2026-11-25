#!/usr/bin/env bash
# jev-route — one classify call per turn; the label IS the route token.
#
# stdin:  the task sentence (one call per turn — this is the only model spend
#         the steward loop makes).
# stdout: `label|probability|margin` (e.g. `flake-change|0.89|0.21`). On a
#         needs_review the row still prints — the top choice is the record.
# Exit:   0 selected · 2 needs_review · 1 error (engine down, bad JSON).
#
# The label it returns is what xs-micro-turn posts as the subject's route and
# what pane-nudge puts in the nudge line, so one classification carries the
# whole turn instead of a prose brief per pane.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
CRITERIA=${CRITERIA:-$ROOT/.agents/skills/router/assets/labels.json}
MIN_P=${MIN_P:-0.8}
MIN_M=${MIN_M:-0.15}

die() { printf 'jev-route: %s\n' "$*" >&2; exit 1; }
command -v jev-decide >/dev/null || die "jev-decide is not on PATH"
[ -r "$CRITERIA" ] || die "no criteria file at $CRITERIA"
[ -t 0 ] && die "task sentence expected on stdin"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

if out=$(jev-decide classify --provider typesafe --text-file - \
  --criteria "$CRITERIA" --min-probability "$MIN_P" --min-margin "$MIN_M" 2>/dev/null); then
  rc=0
else
  rc=$?
fi
[ "$rc" -le 2 ] || die "jev-decide exited $rc"
printf '%s' "$out" >"$tmp"

row=$(jq -r '.decisions.category // empty
  | [.value, (.probability // 0 | tostring), (.margin // 0 | tostring)] | join("|")' "$tmp")
[ -n "$row" ] || die "no decision row in the response"
printf '%s\n' "$row"

status=$(jq -r '.decisions.category.status // "selected"' "$tmp")
[ "$status" = "needs_review" ] && exit 2
exit 0
