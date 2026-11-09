#!/usr/bin/env bash
# appflow-gate.sh — the proof that the database can replace the files.
#
#   appflow-gate.sh roundtrip   read-only: export vs rows vs stored text
#   appflow-gate.sh packet ID   build a packet whose JD came from the database
#
# The deletion rule: nothing is retired until both halves pass, because a file
# that is deleted before the workflow is verified is a file reconstructed from
# memory. `roundtrip` is the leaf check (API only, ~2 s). `packet` is a task, not
# a check, because building one is a nix build and a gate must not spend build
# budget (AGENTS.md).
#
# `roundtrip` asks three questions and fails on any of them:
#   1. the export and the row list describe the same set — same count, same ids;
#   2. a sample of rows has the same field values on both read paths;
#   3. every stored document is non-empty, carries a 64-hex digest, and for a
#      sample the digest matches the bytes the API returns.
set -euo pipefail

api=${APPFLOW_API:-https://delphi.cloudforest-kardashev.ts.net:8450}
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

for cmd in curl jq sha256sum; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "appflow-gate: $cmd is required" >&2
    exit 2
  }
done

get() {
  local path=$1 body
  body=$(curl -sS --max-time 30 "$api$path") || {
    echo "appflow-gate: no answer from $api$path" >&2
    exit 2
  }
  case "$body" in
    '['* | '{'*) printf '%s' "$body" ;;
    *)
      echo "appflow-gate: $api$path did not answer JSON: $(printf '%s' "$body" | head -c 120)" >&2
      exit 2
      ;;
  esac
}

mode=${1:-}
case "$mode" in
  roundtrip | packet) ;;
  *)
    echo "usage: appflow-gate.sh roundtrip | packet ID" >&2
    exit 2
    ;;
esac

if [ "$mode" = "packet" ]; then
  id=${2:-}
  [ -n "$id" ] || {
    echo "appflow-gate: packet needs an application id" >&2
    exit 2
  }

  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  mkdir -p "$work/jd"

  # The corpus stays the corpus: pinned by its own file until it moves to the
  # database (then this copy becomes a query too). Everything the packet knows
  # about *this* application comes from the row and its text.
  for f in resume.json lebenslauf.json; do
    [ -f "$HOME/.config/appflow/$f" ] && cp "$HOME/.config/appflow/$f" "$work/$f"
  done
  [ -f "$work/resume.json" ] || {
    echo "appflow-gate: no ~/.config/appflow/resume.json to build from" >&2
    exit 2
  }

  get "/api/application-document?applicationId=$id" |
    jq -j '[.[] | select(.kind == "jd") | .body][0] // empty' >"$work/jd/$id.txt"
  [ -s "$work/jd/$id.txt" ] || {
    echo "appflow-gate: application $id has no stored jd text" >&2
    exit 1
  }

  out=$(APPFLOW_CONFIG="$work" bash "$repo/scripts/task/appflow-packet.sh" --id "$id" 2>&1) || {
    echo "$out" >&2
    echo "appflow-gate: the packet build failed" >&2
    exit 1
  }
  printf '%s\n' "$out"
  case "$out" in
    /nix/store/*) echo "appflow-gate: packet built from the database for $id" ;;
    *)
      echo "appflow-gate: the build printed no store path" >&2
      exit 1
      ;;
  esac
  exit 0
fi

fail=0
note() {
  printf '%s\n' "$*"
}
bad() {
  printf 'FAIL %s\n' "$*" >&2
  fail=1
}

export_json=$(get /api/applications-export)
list_json=$(get '/api/applications?lim=5000')

export_n=$(jq 'length' <<<"$export_json")
list_n=$(jq 'length' <<<"$list_json")
if [ "$export_n" != "$list_n" ]; then
  bad "export has $export_n records, the row list has $list_n"
else
  note "ok   $export_n applications on both read paths"
fi

ids_export=$(jq -r '[.[].id] | sort | join(",")' <<<"$export_json")
ids_list=$(jq -r '[.[].id] | sort | join(",")' <<<"$list_json")
if [ "$ids_export" != "$ids_list" ]; then
  bad "the export and the row list name different applications"
else
  note "ok   the two lists name the same ids"
fi

# Timestamps are compared as seconds: the two serializers may disagree on the
# fractional part, which is not a data difference.
norm='def n: if type == "string" then sub("\\.[0-9]+"; "") else . end;'

sample=$(jq -r '[.[].id] | (.[0:8] + .[-8:]) | unique | .[]' <<<"$list_json")
checked=0
while IFS= read -r id; do
  [ -n "$id" ] || continue
  rec=$(jq -c --arg id "$id" '.[] | select(.id == $id)' <<<"$export_json")
  rows=$(get "/api/application-get?id=$id")
  row=$(jq -c '.[0] // empty' <<<"$rows")
  if [ -z "$row" ]; then
    bad "$id is in the export but application-get returns nothing"
    continue
  fi
  diff=$(jq -c --argjson e "$rec" --argjson r "$row" "
    $norm
    [\$e | keys[] | select(. != \"id\") | . as \$k
      | select((\$e[\$k] | n) != (\$r[\$k] | n))
      | {field: \$k, export: \$e[\$k], row: (\$r[\$k] // null)}]
    | select(length > 0)
  ")
  if [ -n "$diff" ] && [ "$diff" != "null" ]; then
    bad "$id differs between export and row: $diff"
  fi
  checked=$((checked + 1))
done <<<"$sample"
note "ok   $checked sampled rows agree field for field"

docs=$(get /api/application-documents)
doc_n=$(jq 'length' <<<"$docs")
if [ "$doc_n" -eq 0 ]; then
  note "ok   no documents stored yet (nothing to verify, nothing to delete)"
else
  empty=$(jq '[.[] | select(.chars == 0 or (.sha256 | length) != 64)] | length' <<<"$docs")
  if [ "$empty" -ne 0 ]; then
    bad "$empty stored documents are empty or carry no digest"
  else
    note "ok   $doc_n documents, each non-empty with a digest"
  fi

  verified=0
  while IFS=$'\t' read -r app kind want; do
    [ -n "$app" ] || continue
    tmp=$(mktemp)
    get "/api/application-document?applicationId=$app" |
      jq -j --arg k "$kind" '[.[] | select(.kind == $k) | .body][0] // empty' >"$tmp"
    have=$(sha256sum "$tmp" | cut -d' ' -f1)
    rm -f "$tmp"
    if [ "$have" != "$want" ]; then
      bad "$app/$kind: stored digest does not match the text the API returns"
    fi
    verified=$((verified + 1))
    [ "$verified" -ge 5 ] && break
  done < <(jq -r '.[] | select(.kind == "jd") | [.applicationId, .kind, .sha256] | @tsv' <<<"$docs")
  note "ok   $verified document digests match their bytes"
fi

if [ "$fail" -ne 0 ]; then
  echo "FAIL: the database is not yet the only copy — do not delete a file." >&2
  exit 1
fi
echo "PASS: rows, export and text agree; packet proof is separate (task apps:gate:packet -- <id>)."
