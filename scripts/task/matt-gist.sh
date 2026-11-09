#!/usr/bin/env bash
# scripts/task/matt-gist.sh — the JSON Resume gists are the master copies of the
# CV; lib/matt/profile.json is what the site compiles. These are two different
# documents, so this pulls the gists into a cache and reports what has drifted.
# It never writes into the repo: the page is built by Nix, and a build must not
# depend on a network fetch.
#
#   matt-gist.sh pull    fetch resume.json and lebenslauf.json into the cache
#   matt-gist.sh drift   show how the gist and the page disagree (default)
set -uo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd)
cache=${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig/matt-gist
resume_gist=b7b844737e6469c9160bf41aa8970068
lebenslauf_gist=541b117a49173c4ba8c23b5d126b1fd1
cmd=${1:-drift}

pull() {
  mkdir -p "$cache"
  gh gist view "$resume_gist" --raw >"$cache/resume.json" || return 1
  gh gist view "$lebenslauf_gist" --raw >"$cache/lebenslauf.json" || return 1
  printf 'pulled resume.json and lebenslauf.json into %s\n' "$cache"
}

drift() {
  pull >/dev/null || {
    echo "could not fetch the gists (is gh authenticated?)" >&2
    exit 1
  }
  en="$cache/resume.json"
  profile="$repo/lib/matt/profile.json"

  echo "gist vs compiled page"
  printf '  label   gist: %s\n          page: %s\n' \
    "$(jq -r '.basics.label' "$en")" "$(jq -r '.profile.title' "$profile")"
  printf '  email   gist: %s\n          page: %s\n' \
    "$(jq -r '.basics.email' "$en")" "$(jq -r '.profile.handle' "$profile")"
  printf '  work    gist: %s entries, %s bullets\n          page: %s cards, %s bullets\n' \
    "$(jq '.work | length' "$en")" "$(jq '[.work[].highlights | length] | add' "$en")" \
    "$(jq '.work | length' "$profile")" "$(jq '[.work[].highlights | length] | add' "$profile")"
  echo "  gist roles:"
  jq -r '.work[] | "    - \(.position) @ \(.name)"' "$en"
  echo "  page cards:"
  jq -r '.work[] | "    - \(.title)"' "$profile"
  printf '  skills  gist: %s groups (%s)\n          page: %s groups\n' \
    "$(jq '.skills | length' "$en")" "$(jq -r '[.skills[].name] | join(", ")' "$en")" \
    "$(jq '.stack | length' "$profile")"
  printf '\ncache: %s\n' "$cache"
}

case "$cmd" in
  pull) pull ;;
  drift | "") drift ;;
  *)
    echo "usage: matt-gist.sh [pull|drift]" >&2
    exit 2
    ;;
esac
