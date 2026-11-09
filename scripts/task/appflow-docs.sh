#!/usr/bin/env bash
# appflow-docs.sh — the text behind an application, in the database.
#
#   appflow-docs.sh import [DIR]     upsert DIR/<id>.txt as the `jd` document
#   appflow-docs.sh list             what the database holds, no bodies
#   appflow-docs.sh show ID [KIND]   one document's text
#
# The files are the old home of a job description: `$APPFLOW_JD_DIR/<id>.txt`,
# one per application. This moves them where the rest of the row lives, so a
# description exists only if its application does, and a rebuild finds it with a
# query instead of a directory convention.
#
# A re-run is free. The importer compares the stored `sha256` with the file's and
# skips an unchanged description, so the hourly sync can call this without
# rewriting every row.
#
# DRY=1 prints what would be sent. Exit: 0 clean, 1 a document failed, 2 cannot
# run (no curl/jq, or no directory to import).
set -euo pipefail

# The tailnet front of NpgsqlRest. On delphi itself `http://127.0.0.1:8080` is
# the same API; from any other fleet host this is the address that works.
api=${APPFLOW_API:-https://delphi.cloudforest-kardashev.ts.net:8450}
jd_dir=${APPFLOW_JD_DIR:-${HOME}/.config/appflow/jd}
kind=${APPFLOW_KIND:-jd}

usage() {
  echo "usage: appflow-docs.sh import [DIR] | list | show ID [KIND]" >&2
  exit 2
}

for cmd in curl jq sha256sum; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "appflow-docs: $cmd is required" >&2
    exit 2
  }
done

mode=${1:-}
shift || true

case "$mode" in
  import) ;;
  list) ;;
  show) ;;
  *) usage ;;
esac

if [ "$mode" = "import" ] && [ "$#" -gt 0 ]; then
  jd_dir=$1
fi

# An application id is a slug somebody chose — `*`, `–` and `®` are in the
# archive — so it is percent-encoded before it goes into a query string.
enc() {
  jq -rn --arg v "$1" '$v | @uri'
}

# The API answers JSON or it answers an error page; a body that is not JSON is a
# transport problem, and saying so beats a jq error two steps later.
api_json() {
  local path=$1
  local body
  body=$(curl -sS --max-time 20 "$api$path") || {
    echo "appflow-docs: no answer from $api$path" >&2
    exit 2
  }
  case "$body" in
    '['* | '{'*) printf '%s' "$body" ;;
    *)
      echo "appflow-docs: $api$path did not answer JSON: $(printf '%s' "$body" | head -c 120)" >&2
      exit 2
      ;;
  esac
}

case "$mode" in
  list)
    api_json /api/application-documents |
      jq -r 'if length == 0 then "no documents" else (.[] | [.applicationId, .kind, "\(.chars) chars", .updatedAt] | @tsv) end'
    ;;

  show)
    id=${1:-}
    want=${2:-$kind}
    [ -n "$id" ] || usage
    api_json "/api/application-document?applicationId=$(enc "$id")" |
      jq -r --arg k "$want" '[.[] | select(.kind == $k) | .body][0] // empty'
    ;;

  import)
    [ -d "$jd_dir" ] || {
      echo "appflow-docs: no directory at $jd_dir" >&2
      echo "  nothing to import, or set APPFLOW_JD_DIR / DIR" >&2
      exit 2
    }

    shopt -s nullglob
    files=("$jd_dir"/*.txt)
    if [ "${#files[@]}" -eq 0 ]; then
      echo "appflow-docs: no .txt files in $jd_dir — nothing to import"
      exit 0
    fi

    imported=0
    unchanged=0
    failed=0
    for f in "${files[@]}"; do
      id=$(basename "$f" .txt)
      sha=$(sha256sum "$f" | cut -d' ' -f1)

      have=$(api_json "/api/application-document?applicationId=$(enc "$id")" |
        jq -r --arg k "$kind" '[.[] | select(.kind == $k) | .sha256][0] // ""')
      if [ "$have" = "$sha" ]; then
        unchanged=$((unchanged + 1))
        continue
      fi

      size=$(wc -c <"$f" | tr -d ' ')
      if [ -n "${DRY:-}" ]; then
        echo "would import $id ($size B, $kind)"
        imported=$((imported + 1))
        continue
      fi

      payload=$(jq -n \
        --arg applicationId "$id" \
        --arg kind "$kind" \
        --rawfile body "$f" \
        --arg source "file:$id.txt" \
        --arg sha256 "$sha" \
        '{applicationId: $applicationId, kind: $kind, body: $body, source: $source, sha256: $sha256}')

      resp=$(curl -sS --max-time 30 -w '\n%{http_code}' \
        -X POST -H 'content-type: application/json' \
        --data-binary "$payload" \
        "$api/api/application-document-upsert") || {
        echo "failed $id: the API did not answer" >&2
        failed=$((failed + 1))
        continue
      }
      code=${resp##*$'\n'}
      body=${resp%$'\n'*}
      if [ "$code" != "200" ]; then
        # A foreign-key miss is the common failure and it is a fact about the
        # pipeline, not about the file: say which id has no row.
        echo "failed $id ($code): $(printf '%s' "$body" | head -c 160)" >&2
        failed=$((failed + 1))
        continue
      fi
      imported=$((imported + 1))
      echo "imported $id ($size B, $kind)"
    done

    echo "appflow-docs: $imported imported, $unchanged unchanged, $failed failed"
    [ "$failed" -eq 0 ] || exit 1
    ;;
esac
