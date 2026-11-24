#!/usr/bin/env bash
# Regression fixture for the policy predicates: `ci-substituter-keys` and
# `secrets-path-is-resolved-in-one-place` (corrected 2026-11-23), and
# `shell-script-budget` (added with the 100-line shell ceiling — a new bloated
# script and a grown one must fail; a shrunk or small one must pass).
#
# The failing inputs are checked out of history, not retyped — a fixture that
# paraphrases a bug proves the fixture. `4831b449^` is the workflow that declared
# the substituter keys and never repeated them on the build command (the
# 2722-path rebuild); `ddb19d1c^` is a script that decrypted before the resolver
# existed.
#
# Exit: 0 every case behaves, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# pwd -P, not pwd: `builtins.getFlake` refuses a path that is a symlink, and
# this checkout is reached through one on several hosts.
repo="$(cd "$here/../.." && pwd -P)"
cd "$repo" || exit 2

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git show 4831b449^:.github/workflows/nixcachix.yml >"$tmp/wf-past.yml" 2>/dev/null || {
  echo "fixture: cannot read the past workflow from history" >&2
  exit 2
}
git show ddb19d1c^:scripts/task/alwaysdata.sh >"$tmp/spells.sh" 2>/dev/null || {
  echo "fixture: cannot read the past script from history" >&2
  exit 2
}

cp .github/workflows/nixcachix.yml "$tmp/wf-head.yml"
# The same command with the flags behind the quoted attribute: the key set is
# still repeated, so the rule holds and the position must not matter.
sed 's|--option trusted-public-keys "\$keys" "\.#\${attr}"|"\.#\${attr}" --option trusted-public-keys "$keys"|' \
  "$tmp/wf-head.yml" >"$tmp/wf-flags-after.yml"
# The key option parked on a line that builds nothing: a whole-file match passes
# here, and the command that builds the attribute is the thing that matters.
sed 's|--option trusted-public-keys "\$keys" ||' "$tmp/wf-head.yml" >"$tmp/wf-elsewhere.yml"
printf '%s\n' '# --option trusted-public-keys "$keys"' >>"$tmp/wf-elsewhere.yml"
# A reader that neither spells the path nor resolves one: the gap the
# spelling-only half left open.
printf '%s\n' '#!/usr/bin/env bash' 'secret=$(sops -d --extract "[\"k\"]" "$1")' >"$tmp/reader.sh"

# shell-script-budget: the 101st line of a script nobody recorded, a recorded
# script grown by a line, the same script shrunk, a small file, and a recorded
# file at its ceiling. The recorded subject is kg-check.sh — recorded in
# flake/script-budget.nix at 473 lines.
{ for i in $(seq 1 101); do printf 'echo %s\n' "$i"; done; } >"$tmp/bloat.sh"
{ cat scripts/task/kg-check.sh; printf 'echo grown\n'; } >"$tmp/grown.sh"
head -n 200 scripts/task/kg-check.sh >"$tmp/shrunk.sh"
{ for i in $(seq 1 50); do printf 'echo %s\n' "$i"; done; } >"$tmp/small.sh"

cat >"$tmp/probe.nix" <<EOF
let
  f = builtins.getFlake (toString $repo);
  p = (import $repo/flake/policies.nix {lib = f.inputs.nixpkgs.lib;}).probes;
in {
  ciPast = p.ciKeys (builtins.readFile $tmp/wf-past.yml);
  ciHead = p.ciKeys (builtins.readFile $tmp/wf-head.yml);
  ciFlagsAfter = p.ciKeys (builtins.readFile $tmp/wf-flags-after.yml);
  ciKeyElsewhere = p.ciKeys (builtins.readFile $tmp/wf-elsewhere.yml);
  secretsPast = p.secretsScript "scripts/task/alwaysdata.sh" (builtins.readFile $tmp/spells.sh);
  secretsHead = p.secretsScript "scripts/task/alwaysdata.sh" (builtins.readFile $repo/scripts/task/alwaysdata.sh);
  secretsReader = p.secretsScript "scripts/task/reader.sh" (builtins.readFile $tmp/reader.sh);
  secretsHelper = p.secretsScript "scripts/task/lib/paths.sh" (builtins.readFile $repo/scripts/task/lib/paths.sh);
  shellNew = p.shellScript "scripts/task/bloat.sh" (builtins.readFile $tmp/bloat.sh);
  shellGrowth = p.shellScript "scripts/task/kg-check.sh" (builtins.readFile $tmp/grown.sh);
  shellShrunk = p.shellScript "scripts/task/kg-check.sh" (builtins.readFile $tmp/shrunk.sh);
  shellSmall = p.shellScript "scripts/task/small.sh" (builtins.readFile $tmp/small.sh);
  shellRecorded = p.shellScript "scripts/task/kg-check.sh" (builtins.readFile $repo/scripts/task/kg-check.sh);
  goModuleNew = p.goModule "tools/brandnew/go.mod";
  goModuleRecorded = p.goModule "tools/os/go.mod";
  goModuleService = p.goModule "modules/services/agent-turns/shim/go.mod";
}
EOF

out="$(nix eval --impure --json --file "$tmp/probe.nix" 2>"$tmp/eval.err")" || {
  echo "fixture: nix eval failed" >&2
  sed 's/^/     /' "$tmp/eval.err" >&2
  exit 2
}

fail=0
check() { # name want(fails|passes) key
  local name="$1" want="$2" key="$3" n
  n="$(jq -r --arg k "$key" '.[$k] | length' <<<"$out")"
  if [ "$want" = "fails" ] && [ "${n:-0}" -gt 0 ]; then
    echo "ok   ${name} — ${n} violation(s)"
    return
  fi
  if [ "$want" = "passes" ] && [ "${n:-1}" -eq 0 ]; then
    echo "ok   ${name}"
    return
  fi
  echo "FAIL ${name}: want '${want}', got ${n} for ${key}"
  jq -r --arg k "$key" '.[$k][]' <<<"$out" | sed 's/^/     /'
  fail=1
}

echo "== ci-substituter-keys"
check "the past workflow (keys declared, never repeated) fails" fails ciPast
check "the current workflow passes" passes ciHead
check "flags behind the quoted attribute still pass" passes ciFlagsAfter
check "the key set on a command that builds nothing fails" fails ciKeyElsewhere

echo "== secrets-path"
check "a pre-resolver script fails" fails secretsPast
check "the current script passes" passes secretsHead
check "a reader with neither a literal nor the resolver fails" fails secretsReader
check "the resolver itself is exempt" passes secretsHelper

echo "== shell-script-budget"
check "an unrecorded 101-line script fails" fails shellNew
check "a recorded script grown by a line fails" fails shellGrowth
check "a recorded script shrunk passes" passes shellShrunk
check "a small unrecorded script passes" passes shellSmall
check "a recorded script at its ceiling passes" passes shellRecorded

echo "== tools-go-modules-are-recorded"
check "an unrecorded tools go.mod fails" fails goModuleNew
check "a recorded tools go.mod passes" passes goModuleRecorded
check "a service go.mod under modules/ is out of scope" passes goModuleService

echo "== resolver message"
err="$(NIXCONFIG_ROOT="$tmp" bash -c '. "$1/scripts/task/lib/paths.sh"; secret_get "[\"k\"]"' _ "$repo" 2>&1 >/dev/null)"
if [ "$?" -eq 0 ]; then
  echo "FAIL the resolver reported success with no secrets file"
  fail=1
elif grep -q '\.yaml' <<<"$err"; then
  echo "FAIL the resolver's failure message names a file: $err"
  fail=1
else
  echo "ok   the failure names the plane, not a file"
fi

if [ "$fail" -ne 0 ]; then
  echo "FAIL: a predicate is not the rule it claims"
  exit 1
fi
echo "PASS: the predicates fail on the past mistake and hold on the tree."
