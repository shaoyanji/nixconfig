#!/usr/bin/env bash
# Regression fixture for `task checks:toon:surfaces`
# (scripts/task/toon-surfaces.sh).
#
# The gate holds the agent boundary on prose: an example command that ends in
# `--json` hands the reader raw JSON where the contract is TOON. A real break
# shipped this way — a SKILL.md showing `nix eval --json .#…` bare taught every
# reader the wrong spell. The script takes its file list as arguments "for a
# negative-control fixture", so the mistake is crafted, not a worktree: one
# file with a bare --json command must refuse, a `json-ok:` exempt and the
# toon-piped spelling must pass.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
gate="$repo/scripts/task/toon-surfaces.sh"
[ -f "$gate" ] || { echo "fixture: $gate missing" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

# 1. A bare `nix eval --json` line (no pipe) must fail, the file named —
# a pipe exempts it, since something downstream consumes the JSON. The
# judge only sees a line that *starts* with the command.
cat >"$tmp/bare.md" <<'MD'
Ask the compiler:

    nix eval --json .#inventory.hosts
MD
out=$(cd "$repo" && bash "$gate" "$tmp/bare.md" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'bare.md'; then
  echo "ok   bare --json refused, file named"
else
  echo "FAIL bare file: rc=$rc — expected a refusal"; echo "$out" | tail -6; fail=1
fi

# 2. The honest spellings pass: toon-piped and json-ok exempt.
cat >"$tmp/clean.md" <<'MD'
    nix eval --json .#inventory.hosts | toon -e
    task x --json # json-ok: schema reference
MD
if (cd "$repo" && bash "$gate" "$tmp/clean.md") >/dev/null 2>&1; then
  echo "ok   toon-piped and json-ok lines pass"
else
  echo "FAIL clean file: gate refused honest spellings"; fail=1
fi

# 3. The real surface passes.
if (cd "$repo" && bash "$gate") >/dev/null 2>&1; then
  echo "ok   live file set passes"
else
  echo "FAIL live set: gate refused the tree"; fail=1
fi

[ $fail -eq 0 ] && echo "toon-surfaces:test: all cases pass"
exit $fail
