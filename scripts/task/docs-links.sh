#!/usr/bin/env bash
# Fail when a markdown link in this repo does not resolve.
#
# Two classes, both found in the tree on 2026-10-20:
#   1. `file:///Volumes/...` and `file:///home/<user>/...` — a link to one
#      machine's checkout. It renders as a dead link on every other host, and it
#      leaks a local path into a public document.
#   2. a relative path that is wrong (a moved file, a wrong `../` depth).
#
# Web links and `#anchors` are not checked: the first needs the network, the
# second needs a renderer. A deliberate dangling pointer carries `link-ok:` with
# a reason on the line.
#
# No interpreter: `awk` extracts, `test -e` decides. The previous version needed
# `python3` on PATH, so the gate failed on hosts that do not ship one (delphi,
# 2026-10-22) — a check that cannot run where the tree is edited is not a gate.
# Existence is the CHECK, so the OS resolves `./` and `../` itself; no path
# normalisation is needed or wanted here.
#
# Arguments override the file list (a negative-control fixture); the task calls
# it with none, and then it is every tracked `*.md`.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [ "$#" -gt 0 ]; then
  mapfile -t paths < <(printf '%s\n' "$@")
else
  mapfile -t paths < <(git ls-files '*.md')
fi

absolute=()
broken=()
last=""
dir="."

# One `file<TAB>line<TAB>target` row per candidate link, in file order.
# `match` walks every link on a line, so a line with three links yields three
# rows; the class mirrors the old regex, including a trailing `\r`.
while IFS=$'\t' read -r file line target; do
  # The fragment is the renderer's business: a link resolves when its PATH does.
  target=${target%%#*}
  case $target in
    '' | http://* | https://* | mailto:*) continue ;;
  esac
  case $file in
    "$last") ;;
    *)
      dir=${file%/*}
      if [ "$dir" = "$file" ]; then dir="."; fi
      last=$file
      ;;
  esac
  case $target in
    file:*)
      absolute+=("$file:$line: $target")
      continue
      ;;
  esac
  # A leading `/` is not a repo-relative link: test it as written, never as
  # `$dir$target`, which is a path that cannot exist.
  if [ "${target#/}" != "$target" ]; then
    probe=$target
  else
    probe="$dir/$target"
  fi
  if [ ! -e "$probe" ]; then
    broken+=("$file:$line: $target")
  fi
done < <(
  awk '
    $0 ~ /link-ok:/ { next }
    {
      rest = $0
      while (match(rest, /\[[^]]*\]\([^) \t\r]+/)) {
        target = substr(rest, RSTART, RLENGTH)
        sub(/^\[[^]]*\]\(/, "", target)
        print FILENAME "\t" FNR "\t" target
        rest = substr(rest, RSTART + RLENGTH)
      }
    }
  ' "${paths[@]}"
)

if [ "${#absolute[@]}" -gt 0 ]; then
  echo "FAIL: machine-absolute links; use a repo-relative path"
  printf '  %s\n' "${absolute[@]:0:20}"
fi
if [ "${#broken[@]}" -gt 0 ]; then
  echo "FAIL: links that resolve to nothing"
  printf '  %s\n' "${broken[@]:0:20}"
fi
if [ "${#absolute[@]}" -gt 0 ] || [ "${#broken[@]}" -gt 0 ]; then
  printf '\n%d absolute, %d broken, in %d tracked markdown files.\n' \
    "${#absolute[@]}" "${#broken[@]}" "${#paths[@]}"
  exit 1
fi

printf 'PASS: %d tracked markdown files, every link resolves.\n' "${#paths[@]}"
