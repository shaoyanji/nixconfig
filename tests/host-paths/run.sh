#!/usr/bin/env bash
# Regression fixture for `checks:repo:hostpaths` (scripts/task/host-paths-check.sh).
#
# A gate that has never failed is a claim, not a gate. Each rule is exercised on a
# temp file — a foreign mount, a checkout nested in a home under every word class
# the gate knows, a Windows profile, plaintext key material — and so is each
# exception: the documented storage root passes, the fleet's own repo path passes,
# a home path used as configuration passes, and `host-path-ok:` exempts its line.
#
# Exit: 0 every case behaves, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
gate="$repo/scripts/task/host-paths-check.sh"

[ -f "$gate" ] || {
  echo "fixture: $gate missing" >&2
  exit 2
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
cases=0
run() { # name want_rc needle file-content
  local name="$1" want="$2" needle="$3" body="$4" file rc out
  cases=$((cases + 1))
  file="$tmp/case${cases}.txt"
  printf '%s\n' "$body" >"$file"
  out="$(bash "$gate" "$file" 2>&1)"
  rc=$?
  if [ "$rc" != "$want" ]; then
    echo "FAIL ${name}: exit ${rc}, want ${want}"
    printf '%s\n' "$out" | sed 's/^/     /'
    fail=1
    return
  fi
  if [ -n "$needle" ] && ! grep -qF -- "$needle" <<<"$out"; then
    echo "FAIL ${name}: output lacks '${needle}'"
    printf '%s\n' "$out" | sed 's/^/     /'
    fail=1
    return
  fi
  echo "ok   ${name} (exit ${rc})"
}

run "a portable path passes" 0 "PASS:" 'BLOG="$HOME/Documents/blog"'
run "a foreign mount fails" 1 "a mount that is not the documented storage root" 'MNT=/Volumes/scratch/x'
run "the documented storage root passes" 0 "PASS:" 'MNT=/Volumes/data/media'
run "a checkout nested in a home fails" 1 "a checkout under a home directory" 'BLOG=/Users/someone/projects/blog'
run "a checkout under ~/code fails" 1 "a checkout under a home directory" 'SRC=/home/someone/code/blog'
run "a checkout under ~/src fails" 1 "a checkout under a home directory" 'SRC=/home/someone/src/blog'
run "a checkout under ~/work fails" 1 "a checkout under a home directory" 'SRC=/Users/someone/work/acme'
run "a Windows profile path fails" 1 "a Windows user profile path" 'WIN=C:\Users\someone\projects\blog'
run "a Windows profile path in forward-slash form fails" 1 "a Windows user profile path" 'WIN=C:/Users/someone/projects/blog'
run "a file URL is not a profile path" 0 "PASS:" 'see file:///Users/someone/blog' # host-path-ok: fixture proves the URL does not read as a drive letter
run "a home path used as configuration passes" 0 "PASS:" 'home = "/home/devji"'
run "a checkout written against \$HOME passes" 0 "PASS:" 'SRC=$HOME/code/blog'
run "the fleet repo path passes" 0 "PASS:" 'REPO=/home/someone/Documents/nixconfig' # repo-path-ok: fixture input for the host-paths gate
run "plaintext private key fails" 1 "key material in the clear" '-----BEGIN OPENSSH '"PRIVATE KEY-----"
run "an age secret key fails" 1 "key material in the clear" 'AGE-SECRET-KEY-1QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ'
run "host-path-ok exempts its line" 0 "PASS:" 'MNT=/Volumes/scratch/x host-path-ok: fixture proves the escape hatch'

echo "host-paths fixture: ${cases} cases"
[ "$fail" = 0 ] || exit 1
