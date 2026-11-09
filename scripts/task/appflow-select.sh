#!/usr/bin/env bash
# shellcheck shell=bash
# What a job description would keep, without building a packet.
#
# The corpus selectors are `python3`, so this runs wherever that does; the task
# wraps it in a nix shell on hosts where the base PATH has no interpreter.
#
# Usage:
#   appflow-select.sh --jd FILE [--resume P] [--max-highlights N] [--dump P]
#   appflow-select.sh --id <application>          # $APPFLOW_CONFIG/jd/<id>.txt
set -uo pipefail

repo=$(git rev-parse --show-toplevel)
config="${APPFLOW_CONFIG:-$HOME/.config/appflow}"
selector="$repo/modules/plugins/appflow/select.py"

jd=""
id=""
resume="${APPFLOW_RESUME:-$config/resume.json}"
dump=""
max_highlights=4
max_projects=4
format="${FORMAT:-text}"

usage() { sed -n '4,12p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --jd) jd="${2:-}"; shift 2 ;;
    --id) id="${2:-}"; shift 2 ;;
    --resume) resume="${2:-}"; shift 2 ;;
    --dump) dump="${2:-}"; shift 2 ;;
    --max-highlights) max_highlights="${2:-}"; shift 2 ;;
    --max-projects) max_projects="${2:-}"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "appflow-select: unknown argument $1" >&2; exit 2 ;;
  esac
done

[ -f "$selector" ] || { echo "appflow-select: $selector is missing" >&2; exit 2; }
[ -f "$resume" ] || { echo "appflow-select: no resume at $resume" >&2; exit 2; }

if [ -z "$jd" ] && [ -n "$id" ]; then
  jd="$config/jd/$id.txt"
  [ -f "$jd" ] || {
    echo "appflow-select: no job description for $id at $jd" >&2
    echo "  save the ad there, or pass --jd FILE" >&2
    exit 2
  }
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [ -n "$jd" ]; then
  python3 "$selector" --resume "$resume" --jd "$jd" \
    --out "$work/resume.json" --audit "$work/audit.json" \
    --max-highlights "$max_highlights" --max-projects "$max_projects" >/dev/null || exit 1
else
  # No description is a legitimate call: it says what the corpus holds, which is
  # how a volume grows without a page budget.
  python3 "$selector" --resume "$resume" \
    --out "$work/resume.json" --audit "$work/audit.json" >/dev/null || exit 1
fi

if [ -n "$dump" ]; then
  cp "$work/resume.json" "$dump"
  echo "wrote     $dump"
fi

case "$format" in
  toon) toon -e <"$work/audit.json" ;;
  json) cat "$work/audit.json" ;;
  *)
    jq -r '
      if .mode == "passthrough" then
        "no job description: the corpus is the CV (\(.reason))"
      else
        "terms     \(.jd.terms | length) ranked, strongest first: "
          + ([.jd.terms[:6][] | "\(.term)(\(.weight))"] | join(" ")),
        "work",
        (.work[] | "  \(if .matched then "match" else "lead " end)  \(.name)  \(.kept)/\(.of) kept"),
        "projects  \(.projects.kept | join(", "))",
        "skills",
        (.skills[] | "  \(.name)  \(.kept)/\(.of) keywords")
      end
    ' "$work/audit.json"
    ;;
esac
