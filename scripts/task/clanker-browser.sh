#!/usr/bin/env bash
# agent-browser on InstaBox clanker: the same argv a local run would take, the
# machine's stdout and exit status back. Quoting is the whole job — the eval
# script has spaces and quotes, and `instabox.sh exec` joins its arguments, so
# each one is double-quoted here (backslash-escaped argv splitting fails on
# clanker's side: the `\(` form arrives as a syntax error).
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

print_command=false
if [ "${1:-}" = "--print-command" ]; then
  print_command=true
  shift
fi
[ $# -gt 0 ] || { printf 'usage: clanker-browser.sh [--print-command] <agent-browser args...>\n' >&2; exit 2; }

quote() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//\$/\\\$}
  s=${s//\`/\\\`}
  printf '"%s"' "$s"
}

cmd="agent-browser "
for arg in "$@"; do
  cmd+="$(quote "$arg") "
done
cmd=${cmd% }

if $print_command; then
  printf '%s\n' "$cmd"
  exit 0
fi

exec bash "$here/instabox.sh" exec clanker "$cmd"
