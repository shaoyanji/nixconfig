#!/usr/bin/env bash
# Fail when a markdown link in this repo does not resolve.
#
# Classes checked:
#   1. `file:///...` — a link to one machine's checkout; dead elsewhere and a
#      local path leaked into a public document.
#   2. a relative path that is wrong (a moved file, a wrong `../` depth).
#   3. a `#anchor` that names no heading in its target file — the target exists,
#      so class 2 misses it, but a renamed section breaks the link all the same.
#   4. reference-style `[id]: path` definitions, which an inline-only scan misses.
#
# What is NOT judged: web links (network) and anchors into non-markdown targets or
# into a heading whose slug this approximation cannot reproduce (keep `link-ok:`
# for those). Fenced code blocks are skipped — a documentation example showing
# markdown-link syntax is not a link, and judging it forced escapes nobody wanted.
#
# A deliberate dangling pointer carries `link-ok:` with a reason on the line.
#
# No interpreter: `awk` extracts, `test -e` decides, `awk` slugs headings. The
# previous version needed `python3`, so the gate failed on hosts that do not ship
# one (delphi, 2026-10-22) — a check that cannot run where the tree is edited is
# not a gate. Existence is the CHECK, so the OS resolves `./` and `../` itself.
#
# Arguments override the file list (a negative-control fixture); the task calls it
# with none, and then it is every tracked `*.md`.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [ "$#" -gt 0 ]; then
  mapfile -t paths < <(printf '%s\n' "$@")
else
  mapfile -t paths < <(git ls-files '*.md')
fi

absolute=()
broken=()
anchors=()
last=""
dir="."

# One `file<TAB>line<TAB>target` row per candidate link, in file order. `match`
# walks every link on a line, so a line with three links yields three rows.
# Fence state resets per file: a ``` or ~~~ line toggles it and is itself skipped.
while IFS=$'\t' read -r file line target; do
  case $file in
    "$last") ;;
    *)
      dir=${file%/*}
      if [ "$dir" = "$file" ]; then dir="."; fi
      last=$file
      ;;
  esac

  frag=""
  path=$target
  case $target in
    *'#'*)
      frag=${target#*#}
      path=${target%%#*}
      ;;
  esac

  case $path in
    # A bare `#frag` still needs its heading; web and mailto are the only skips.
    # (`${path:-x}` was tried first: it made this branch continue, so same-file
    # anchors were never validated and the fixture caught nothing.)
    '') ;;
    http://* | https://* | mailto:*) continue ;;
  esac

  probe=""
  case $path in
    file:*)
      absolute+=("$file:$line: $path")
      continue
      ;;
    '')
      probe=$file
      ;;
    /*)
      probe=$path
      ;;
    *)
      probe="$dir/$path"
      if [ ! -e "$probe" ]; then
        broken+=("$file:$line: $path")
        continue
      fi
      ;;
  esac

  if [ -e "$probe" ]; then
    # Anchor validation is limited to markdown targets: headings are the only
    # thing that defines an in-repo anchor, and an asset's fragment is its own.
    if [ -n "$frag" ] && [ -f "$probe" ]; then
      case $probe in
        *.md | *.mdx | *.markdown)
          if ! awk -v want="$frag" '
            function slug(s,   t) {
              t = tolower(s)
              gsub(/`/, "", t)
              gsub(/<[^>]*>/, "", t)
              # Everything non-ASCII or punctuation goes; space and hyphen stay.
              gsub(/[^a-z0-9 _-]/, "", t)
              gsub(/[ \t]+/, "-", t)
              return t
            }
            /^[ \t]*(```|~~~)/ { next }
            /^#{1,6}[ \t]+/ {
              h = $0
              sub(/^#{1,6}[ \t]+/, "", h)
              sub(/[ \t]+$/, "", h)
              if (slug(h) == want) found = 1
            }
            END { exit(found ? 0 : 1) }
          ' "$probe"; then
            anchors+=("$file:$line: #${frag} in ${path:-$file}")
          fi
          ;;
      esac
    fi
  fi
done < <(
  awk '
    FNR == 1 { fence = 0 }
    $0 ~ /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    $0 ~ /link-ok:/ { next }
    {
      rest = $0
      while (match(rest, /\[[^]]*\]\([^) \t\r]+/)) {
        target = substr(rest, RSTART, RLENGTH)
        sub(/^\[[^]]*\]\(/, "", target)
        print FILENAME "\t" FNR "\t" target
        rest = substr(rest, RSTART + RLENGTH)
      }
      if (match($0, /^[ \t]*\[[^]]*\]:[ \t]+[^ \t\r]+/)) {
        def = substr($0, RSTART, RLENGTH)
        # A footnote definition is not a link. `[^^]` was tried first and does not
        # behave as a negated class here (mawk): the rule silently never fired, so
        # the caret is excluded by testing the matched id instead.
        if (def !~ /^[ \t]*\[\^/) {
          sub(/^[ \t]*\[[^]]*\]:[ \t]+/, "", def)
          print FILENAME "\t" FNR "\t" def
        }
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
if [ "${#anchors[@]}" -gt 0 ]; then
  echo "FAIL: anchors that name no heading in the target"
  printf '  %s\n' "${anchors[@]:0:20}"
  echo "      (a heading slug is lowercased, stripped of punctuation, spaces to '-')"
fi
if [ "${#absolute[@]}" -gt 0 ] || [ "${#broken[@]}" -gt 0 ] || [ "${#anchors[@]}" -gt 0 ]; then
  printf '\n%d absolute, %d broken, %d anchor, in %d tracked markdown files.\n' \
    "${#absolute[@]}" "${#broken[@]}" "${#anchors[@]}" "${#paths[@]}"
  exit 1
fi

printf 'PASS: %d tracked markdown files, every link and anchor resolves.\n' "${#paths[@]}"
