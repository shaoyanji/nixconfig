#!/usr/bin/env bash
# scripts/task/pages-deploy.sh — deploy a directory, then wait until it is real.
#
#   pages-deploy.sh DIR --project-name=NAME --branch=main [wrangler args...]
#
# WHY THIS EXISTS: wrangler prints "Deployment complete!" the moment the upload
# finishes, and Pages may attach the deployment's asset manifest afterwards. A
# deploy that says complete and answers 404 on `/` is the failure this waits out:
# the build was fine, the CLI was early, and rolling production back over it
# throws away a good deployment. The readiness signal is the deployment's own
# pages.dev hostname serving `/`, not the CLI's exit code.
set -euo pipefail

dir=${1:?usage: pages-deploy.sh DIR --project-name=NAME --branch=BRANCH [wrangler args...]}
shift
project=""
for arg in "$@"; do
  case "$arg" in
    --project-name=*) project=${arg#--project-name=} ;;
  esac
done
[ -n "$project" ] || {
  echo "pages-deploy: --project-name= is required" >&2
  exit 2
}

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
log=$(mktemp "${TMPDIR:-/tmp}/pages-deploy.XXXXXX")
trap 'rm -f "$log"' EXIT

bash "$repo/scripts/task/wrangler.sh" pages deploy "$dir" "$@" 2>&1 | tee "$log"

# The hostname is `<hash>.<project><suffix>.pages.dev` — the suffix is assigned by
# Pages, not derived from the project name, so match the shape and not the name.
url=$(grep -oE 'https://[a-z0-9.-]+\.pages\.dev' "$log" | tail -1 || true)
if [ -z "$url" ]; then
  echo "pages-deploy: no deployment URL in wrangler's output — refusing to call this a success" >&2
  exit 1
fi

# A fresh deployment answers 404 for a while: the asset manifest attaches per
# path, so `/` can serve while `/contact/thanks/` is still missing. Wait for every
# page the artifact carries — derived from the tree, not a list that goes stale
# the moment a section is added. 120 s is generous for a static site and still
# short enough that a broken deploy fails the task.
paths=()
while IFS= read -r file; do
  rel=${file#"$dir"}
  page=${rel%/index.html}
  paths+=("${page:-}/")
# -L because $dir is the `nix build --out-link` symlink: find does not descend a
# symlink given as its own argument, so without it this counted zero pages and
# refused a deployment that had already succeeded.
done < <(find -L "$dir" -name index.html | sort)
[ "${#paths[@]}" -gt 0 ] || {
  echo "pages-deploy: $dir carries no index.html — refusing to deploy an empty artifact" >&2
  exit 1
}

wait=${PAGES_WAIT_SECONDS:-120}
deadline=$((SECONDS + wait))
pending=""
while [ "$SECONDS" -lt "$deadline" ]; do
  pending=""
  for path in "${paths[@]}"; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url$path" || true)
    [ "$code" = 200 ] || pending="$pending ${path}(${code:-none})"
  done
  [ -z "$pending" ] && break
  sleep 2
done

if [ -n "${pending:-}" ]; then
  echo "pages-deploy: ${wait}s after the upload, $url still answers:${pending} — the deployment is not serving; do not ship this" >&2
  exit 1
fi
printf 'pages-deploy: %s is live (200 on %d path(s))\n' "$url" "${#paths[@]}"
