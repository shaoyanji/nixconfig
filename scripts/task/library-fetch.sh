#!/usr/bin/env bash
# Fetches one GitHub release asset into the shared library, non-interactively.
#
# Two rules this wrapper enforces, because the library's consumers are NON-Nix
# machines (pentest targets, research boxes) that cannot rebuild or relink:
#   * `--asset` is required. eget's interactive selector appears when it cannot
#     narrow the release to one asset, and a prompt is a hang in a schedule.
#   * the downloaded file must be STATICALLY linked. A dynamic glibc build is a
#     binary that runs on the workstation that fetched it and nowhere else, so
#     it is rejected into $ROOT/.rejected/ instead of entering the library.
#
# Each fetch is recorded in $ROOT/.library.tsv (sha256, repo, tag, asset, date,
# dest) — provenance is the one fact a file cannot carry about itself.
#
# usage: library-fetch.sh --repo OWNER/REPO --asset SUBSTR [--tag TAG]
#                         [--dest bin-x86|bin-aarch64|bin-script|appimages]
#                         [--sha256 HEX] [--name NAME]
# exit: 0 fetched and static · 1 fetch or linkage rejected · 2 usage
set -euo pipefail

ROOT="${LIBRARY_ROOT:-}"
if [ -z "$ROOT" ]; then
  for d in /Volumes/data /srv/data; do
    [ -d "$d" ] && ROOT="$d" && break
  done
fi
[ -n "$ROOT" ] && [ -d "$ROOT" ] || {
  echo "library fetch: no library root (/Volumes/data, /srv/data)" >&2
  exit 1
}

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

repo="" asset="" tag="" dest="bin-x86" sha="" name=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:?--repo needs OWNER/REPO}"; shift 2 ;;
    --asset) asset="${2:?--asset needs a substring}"; shift 2 ;;
    --tag) tag="${2:?--tag needs a value}"; shift 2 ;;
    --dest) dest="${2:?--dest needs a directory}"; shift 2 ;;
    --sha256) sha="${2:?--sha256 needs a value}"; shift 2 ;;
    --name) name="${2:?--name needs a value}"; shift 2 ;;
    -h | --help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "library fetch: unknown argument $1" >&2; exit 2 ;;
  esac
done

[ -n "$repo" ] && [ -n "$asset" ] || {
  echo "library fetch: --repo and --asset are both required (see --help)" >&2
  exit 2
}

case "$dest" in
  bin-x86 | bin-aarch64 | bin-script | appimages) ;;
  *) echo "library fetch: --dest must be bin-x86, bin-aarch64, bin-script or appimages" >&2; exit 2 ;;
esac

target="$ROOT/$dest"
[ -d "$target" ] || { echo "library fetch: $target does not exist" >&2; exit 1; }

args=("$repo" --asset "$asset" --to "$target")
[ -n "$tag" ] && args+=(--tag "$tag")
[ -n "$sha" ] && args+=(--verify-sha256 "$sha")

echo "library fetch: $repo asset~$asset -> $dest${tag:+ (tag $tag)}"

# eget prints whatever it wrote, but a schedule needs a fact, not stdout: snapshot
# the directory and diff it. `find -newer` was the first attempt and it lied —
# eget writes immediately, so a marker created afterwards is always newer.
before=$(mktemp)
after=$(mktemp)
find "$target" -maxdepth 1 -type f -printf '%s %T@ %p\n' | sort >"$before"

log=$(mktemp)
trap 'rm -f "$before" "$after" "$log"' EXIT
nix run --builders "" nixpkgs#eget -- "${args[@]}" 2>&1 | tee "$log"
# The resolved tag is in the download URL; recording "latest" would make the
# manifest un-reproducible the moment a new release lands.
resolved=$(sed -nE 's|.*/releases/download/([^/]+)/.*|\1|p' "$log" | head -1)

find "$target" -maxdepth 1 -type f -printf '%s %T@ %p\n' | sort >"$after"
newest=$(comm -13 "$before" "$after" | awk '{ print $3 }' | head -1)
if [ -z "$newest" ]; then
  # eget skips the write when the asset is unchanged; say so instead of lying.
  echo "library fetch: eget reported success but wrote nothing new to $target" >&2
  exit 1
fi
if [ -n "$name" ] && [ "$(basename "$newest")" != "$name" ]; then
  mv -f "$newest" "$target/$name"
  newest="$target/$name"
fi

# One judgment, from the audit's own probe: arch, linkage, glibc floor.
IFS=$'\t' read -r digest arch linkage floor _ < <(bash "$here/library-audit.sh" --probe "$newest")
if [ "$linkage" != static ]; then
  rejected="$ROOT/.rejected"
  mkdir -p "$rejected"
  mv -f "$newest" "$rejected/$(basename "$newest")"
  echo "library fetch: REJECTED $(basename "$newest") — $linkage${floor:+ (glibc >= $floor)}; moved to .rejected/" >&2
  echo "library fetch: pick a statically linked asset (usually a -musl or static release)" >&2
  exit 1
fi

printf 'library fetch: wrote %s — %s %s, sha256 %s\n' "${newest#"$ROOT"/}" "$arch" "$linkage" "$digest"
printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$digest" "$repo" "${tag:-${resolved:-unknown}}" "$asset" "$(date -Iseconds)" "${newest#"$ROOT"/}" >>"$ROOT/.library.tsv"
echo "library fetch: recorded provenance in .library.tsv"
