#!/usr/bin/env bash
# Fixture for lib/typeset.nix — the two rules every PDF build answers to.
#
# The rule is not restated here: the shell fragment is rendered out of the Nix
# file itself (`nix eval --raw`), so this fixture fails when the rule changes
# shape, not only when a document does. The documents are compiled by the same
# pinned typst the builders use.
#
#   spill.typ    one page of material, then two lines on a second page
#   full.typ     a second page carrying a real section
#   thin.typ     one short page
#   nolabel.typ  a template that forgot its <typeset> report
#
# Nothing is built: the tools are resolved onto PATH (or from the flake.lock
# nixpkgs, cached as a GC root) and the rule runs as shell. A check may not spend
# build budget, which is why the packet — whose build is a typst derivation — is
# asserted by `nix build .#artifacts.appflow-packet-example` instead.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

command -v nix >/dev/null 2>&1 || {
  echo "fixture: nix is required (it renders the rule out of lib/typeset.nix)" >&2
  exit 2
}
for f in spill full thin nolabel; do
  [ -f "$here/fixtures/$f.typ" ] || {
    echo "fixture: fixtures/$f.typ is missing" >&2
    exit 2
  }
done

cache="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig-typeset"
pin() { # pin <tool> — PATH first, then the flake.lock nixpkgs, kept as a GC root
  local tool="$1" link="$cache/$1"
  if command -v "$tool" >/dev/null 2>&1; then
    command -v "$tool"
    return 0
  fi
  if [ ! -x "$link/bin/$tool" ]; then
    mkdir -p "$cache"
    nix build --impure --out-link "$link" --expr \
      "let f = builtins.getFlake \"$repo\"; in f.inputs.nixpkgs.legacyPackages.\${builtins.currentSystem}.$tool" \
      >/dev/null 2>&1 || return 1
  fi
  [ -x "$link/bin/$tool" ] || return 1
  printf '%s\n' "$link/bin/$tool"
}

TYPST="$(pin typst || true)"
JQ="$(pin jq || true)"
[ -n "$TYPST" ] || {
  echo "fixture: typst could not be resolved" >&2
  exit 2
}
[ -n "$JQ" ] || {
  echo "fixture: jq could not be resolved" >&2
  exit 2
}
PATH="$(dirname "$TYPST"):$(dirname "$JQ"):$PATH"

# The rule compiles with `--root work` and names `work/<file>`, so the documents
# sit in a work/ directory under the cwd, exactly as inside a derivation.
mkdir -p "$work/work"
cp "$here"/fixtures/*.typ "$work/work/"

rule() { # rule <file> <budget> — lib/typeset.nix's check, not a copy of it
  nix eval --raw --impure --expr "
    let f = builtins.getFlake \"$repo\";
        pkgs = f.inputs.nixpkgs.legacyPackages.\${builtins.currentSystem};
    in (import $repo/lib/typeset.nix {inherit pkgs;}).check {
      source = \"work/$1\"; budget = $2; doc = \"$1\";
    }"
}

fail=0
ran=()
EXPECTED=(
  "a spillover held to one page is refused on the count"
  "the same spillover is refused on the content floor"
  "a final page with real content passes"
  "a single short page is exempt from the floor"
  "a template with no report is refused"
)

case_() { # case_ <name> <file> <budget> <want rc> <want text>
  local name="$1" file="$2" budget="$3" want="$4" text="$5" out rc
  ran+=("$name")
  out="$(cd "$work" && bash -c "$(rule "$file" "$budget")" 2>&1)" && rc=0 || rc=$?
  if [ "$rc" != "$want" ]; then
    fail=1
    printf 'FAIL %s: exit %s, want %s\n%s\n' "$name" "$rc" "$want" "$out" >&2
  elif ! grep -qF -- "$text" <<<"$out"; then
    fail=1
    printf 'FAIL %s: the output does not say "%s"\n%s\n' "$name" "$text" "$out" >&2
  else
    printf 'ok   %s\n' "$name"
  fi
}

case_ "a spillover held to one page is refused on the count" spill.typ 1 1 "the budget is 1"
case_ "the same spillover is refused on the content floor" spill.typ 2 1 "spillover, not a page"
case_ "a final page with real content passes" full.typ 2 0 "typeset: full.typ: 2 page(s)"
case_ "a single short page is exempt from the floor" thin.typ 1 0 "typeset: thin.typ: 1 page(s)"
case_ "a template with no report is refused" nolabel.typ 1 1 "no <typeset> report"

# Coverage in both directions: an EXPECTED case that no longer runs fails, and so
# does a case that runs without being declared.
ran_set="$(printf '%s\n' "${ran[@]}")"
expected_set="$(printf '%s\n' "${EXPECTED[@]}")"
for c in "${EXPECTED[@]}"; do
  grep -qxF -- "$c" <<<"$ran_set" || {
    echo "FAIL coverage: expected case did not run: $c" >&2
    fail=1
  }
done
for c in "${ran[@]}"; do
  grep -qxF -- "$c" <<<"$expected_set" || {
    echo "FAIL coverage: case is not declared in EXPECTED: $c" >&2
    fail=1
  }
done

if [ "$fail" != 0 ]; then
  echo "typeset fixture: FAILED" >&2
  exit 1
fi
echo "typeset fixture: ${#EXPECTED[@]} cases ok (all expected)"
