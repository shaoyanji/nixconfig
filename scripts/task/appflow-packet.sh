#!/usr/bin/env bash
# shellcheck shell=bash
# Build an application packet with Nix: the artifact is a store path.
#
# One base file — a JSON Resume at ~/.config/appflow/resume.json — plus the
# application record from the hub's API. `nix build` evaluates
# modules/plugins/appflow/packet.nix, so typst runs in the sandbox and nothing is
# written into a state directory.
#
# Usage:
#   appflow-packet.sh --id <application> [--resume P] [--letter P] [--out <link>]
set -euo pipefail

API="${EMAIL_ARCHIVE_API:-http://127.0.0.1:8080}"
CONFIG="${APPFLOW_CONFIG:-$HOME/.config/appflow}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/email-archive/packets"
REPO="$(git rev-parse --show-toplevel)"

id=""
out=""
resume=""
letter=""
example=0

usage() { sed -n '4,12p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --id) id="${2:-}"; shift 2 ;;
    --resume) resume="${2:-}"; shift 2 ;;
    --letter) letter="${2:-}"; shift 2 ;;
    --out) out="${2:-}"; shift 2 ;;
    --example) example=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) echo "appflow-packet: unknown argument $1" >&2; exit 2 ;;
  esac
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Today's date is an input, not a clock read: the build runs with
# SOURCE_DATE_EPOCH=1980-01-01, so `datetime.today()` inside typst is not today.
today="$(date +%F)"
name="application"
if [ -n "$id" ]; then
  command -v curl >/dev/null || { echo "appflow-packet: curl is required" >&2; exit 2; }
  # The record supplies the diff and the language; a JSON Resume in `en` renders
  # English headings, anything else German (the resume's own "german").
  curl -fsS --max-time 20 "$API/api/application-get?id=$(jq -rn --arg v "$id" '$v|@uri')" \
    | jq --arg v "$id" '
        (.[0] // error("no application " + $v))
        | {
            id,
            company,
            role,
            apply_url: (.applyUrl // ""),
            language: (if (.language // "") == "en" or (.language // "") == "english_us"
                       then "en" else "de" end)
          }' | jq --arg d "$today" '. + {date: $d}' >"$work/application.json"
  name="$id"
else
  if [ "$example" = 1 ]; then
    jq -n --arg d "$today" \
      '{company: "Beispiel GmbH", role: "Platform Engineer", apply_url: "", language: "de", date: $d}' \
      >"$work/application.json"
    name="example"
  else
    jq -n --arg d "$today" '{language: "de", date: $d}' >"$work/application.json"
  fi
fi

# The fixture is committed and fictional, so the build is testable on any host
# with no private data and no database: `task agents:apps:packet EXAMPLE=1`.
if [ "$example" = 1 ]; then
  resume="${resume:-$REPO/modules/plugins/appflow/templates/example/resume.json}"
  letter="${letter:-$REPO/modules/plugins/appflow/templates/example/letter.json}"
fi

resume_src="${resume:-$CONFIG/resume.json}"
if [ ! -f "$resume_src" ]; then
  echo "appflow-packet: no resume.json at $resume_src" >&2
  echo "  it is a JSON Resume (jsonresume.org); put it in $CONFIG/, or pass --resume." >&2
  exit 2
fi
cp "$resume_src" "$work/resume.json"

# The packet is the document that carries what no page does: a phone number and a
# street address. They are decrypted here, at build time, from
# modules/secrets/pii.yaml — the corpus never holds them, and the fictional
# example never borrows them.
pii_json="$CONFIG/pii.json"
if [ "$example" != 1 ] && [ ! -s "$pii_json" ] && [ -x "$REPO/scripts/task/pii.sh" ]; then
  APPFLOW_PII="$pii_json" "$REPO/scripts/task/pii.sh" sync >/dev/null 2>&1 || true
fi
if [ "$example" != 1 ] && [ -s "$pii_json" ]; then
  jq --slurpfile pii "$pii_json" '.basics = ((.basics // {}) * ($pii[0].basics // {}))' \
    "$work/resume.json" >"$work/resume.private.json"
  mv "$work/resume.private.json" "$work/resume.json"
elif [ "$example" != 1 ]; then
  echo "appflow-packet: no $pii_json — the CV carries no phone or street address" >&2
fi

letter_clause=""
letter_src="${letter:-$CONFIG/letter.json}"
if [ -f "$letter_src" ]; then
  cp "$letter_src" "$work/letter.json"
  letter_clause="letter = $work/letter.json;"
else
  echo "appflow-packet: no letter.json — building the CV only" >&2
fi

expr="let
  repo = $REPO;
  flake = builtins.getFlake (\"path:\" + toString repo);
  pkgs = flake.inputs.nixpkgs.legacyPackages.\${builtins.currentSystem};
in
  (import (repo + \"/modules/plugins/appflow/packet.nix\") { inherit pkgs; }).mkPacket {
    application = $work/application.json;
    resume = $work/resume.json;
    $letter_clause
    name = \"$name\";
  }"

store_path="$(nix build --impure --no-link --print-out-paths --expr "$expr")"
echo "artifact  $store_path"
ls -1 "$store_path"

target="${out:-$STATE/$name}"
mkdir -p "$(dirname "$target")"
# A symlink, not a copy: the artifact stays the store path, and the stable name is
# how a human (or the application record) finds it.
ln -sfn "$store_path" "$target"
echo "linked    $target"
