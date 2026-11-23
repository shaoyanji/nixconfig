#!/usr/bin/env bash
# apps-scout.sh — one scouted lead, written through the pipeline's own columns.
#
# Scouting finds roles a sweep turned up, not applications already sent. The
# table has no family column and no owner column, so a lead maps onto what does
# exist, the same way the mail hub maps the employers it discovers:
#   family  -> origin `scout:<family>` (indexed, and the provenance it is)
#   summary -> notes (the row's one free-text column)
#   owner   -> the status line, where apps:list and apps:search show it
#   status  -> `lead (scout <family>, owner <owner>)`, which stages as `lead`
# When a real owner column lands, the owner moves there and the status default
# goes back to `lead (scout <family>)`; until then one line says where it is.
#
# Writes go through apps-db.sh, so the stage, the id slug and the API's
# all-keys-required contract stay in one place instead of a second writer here.
#
# Exit 2 = bad input (nothing written). A refused write is the API's status.
set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
db="$root/scripts/task/apps-db.sh"

usage() {
  cat >&2 <<'EOF'
usage: apps-scout.sh --family F --company C --role R --summary S
                     [--owner O] [--status S] [--url U] [--fit 1-5] [--id ID] [--dry]

  --family   devops | sre | platform | infrastructure (required; case-insensitive)
  --company  employer as it writes it (required)
  --role     the title on the ad (required)
  --summary  one line: why this role is worth a packet (stored as notes)
  --owner    the lane that follows it up (default agent:apps)
  --status   override the derived status; the stage still follows it
  --url      application URL
  --fit      1-5, the same scale the tracker uses
  --id       reuse a scan's slug instead of the company+role default
  --dry      print the record and write nothing
EOF
}

family=""; company=""; role=""; summary=""
owner="agent:apps"; status=""; url=""; fit=""; id=""; dry=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --family) family=${2:-}; shift 2 ;;
    --company) company=${2:-}; shift 2 ;;
    --role) role=${2:-}; shift 2 ;;
    --summary) summary=${2:-}; shift 2 ;;
    --owner) owner=${2:-}; shift 2 ;;
    --status) status=${2:-}; shift 2 ;;
    --url) url=${2:-}; shift 2 ;;
    --fit) fit=${2:-}; shift 2 ;;
    --id) id=${2:-}; shift 2 ;;
    --dry) dry=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) echo "apps-scout: unknown flag $1" >&2; usage; exit 2 ;;
  esac
done

family=$(printf '%s' "$family" | tr '[:upper:]' '[:lower:]')
case "$family" in
  devops | sre | platform | infrastructure) ;;
  infra) family=infrastructure ;;
  "") echo "apps-scout: --family is required" >&2; exit 2 ;;
  *)
    echo "apps-scout: --family '$family' is not devops, sre, platform or infrastructure" >&2
    exit 2
    ;;
esac

for pair in "company:$company" "role:$role" "summary:$summary" "owner:$owner"; do
  [ -n "${pair#*:}" ] || { echo "apps-scout: --${pair%%:*} is required" >&2; exit 2; }
done

# A summary is one line: a newline in notes is a paragraph the row cannot show,
# and the tab the TOON reader splits on would corrupt the record.
summary=$(printf '%s' "$summary" | tr '\n\t' '  ' | sed -E 's/  +/ /g; s/^ //; s/ $//')

if [ -n "$fit" ] && ! [[ "$fit" =~ ^[1-5]$ ]]; then
  echo "apps-scout: --fit must be 1-5" >&2
  exit 2
fi

[ -n "$status" ] || status="lead (scout $family, owner $owner)"

args=(--company "$company" --role "$role" --status "$status" --notes "$summary"
  --origin "scout:$family")
[ -n "$url" ] && args+=(--apply-url "$url")
[ -n "$fit" ] && args+=(--fit "$fit")
[ -n "$id" ] && args+=(--id "$id")
[ "$dry" = 1 ] && args+=(--dry)

FORMAT=${FORMAT:-toon} bash "$db" add "${args[@]}"
