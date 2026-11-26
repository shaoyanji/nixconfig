#!/usr/bin/env bash
# Regression fixture for the per-file alias gate
# (scripts/task/nix-style-check.sh), wired as `checks:nix:style` in
# checks:quick.
#
# A gate that cannot fail is no gate, so the failing input is checked out of
# history, not retyped: `2fe0c687^` is the tree right before the unification —
# flake/policies.nix carried lib.filter/lib.elem/lib.hasAttr minorities against
# a builtins-majority file, and flake/epistemics.nix one lib.filter. The gate
# must refuse that tree, name the files, and accept the current one.
# (lib/nix-files.nix rides along as the honest control: its pre-fix version
# mixes no aliases — the map|>concatStringsSep it carried is a different class
# this gate does not lint, and the fixture asserts the gate leaves it alone.)
#
# A second rule locks the filter|>length → lib.count class (763eaa83): case 4
# seeds the converted shape and must fail naming the rule; case 5 seeds the
# honest controls (length inside a filter predicate, length on a non-filter
# source) and must pass — the line-end anchor is what tells them apart.
# A third rule locks map (x: x.f) → catAttrs "f" (lib-pipe-catattrs): case 6
# seeds the projection and must fail; case 7's honest lambdas (nested path,
# computed body, record body) must pass — the one-dot backreference shape is
# what tells them apart.
#
# Exit: 0 every case behaves, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd -P)"
cd "$repo" || exit 2

gate="$repo/scripts/task/nix-style-check.sh"
[ -f "$gate" ] || { echo "fixture: $gate missing" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# The past tree: same file set, checked out of the commit before the gate and
# the unification landed.
mkdir -p "$tmp/flake" "$tmp/lib"
for p in flake/policies.nix flake/epistemics.nix lib/nix-files.nix; do
  git show "2fe0c687^:$p" >"$tmp/$p" 2>/dev/null || { echo "fixture: cannot read 2fe0c687^:$p" >&2; exit 2; }
done

fail=0

# 1. The current tree passes.
if bash "$gate" >/dev/null 2>&1; then
  echo "ok   current tree passes the gate"
else
  echo "FAIL current tree: gate refused the shipped files"
  fail=1
fi

# 2. The past mistake fails — and names the mixing files.
out="$(bash "$gate" "$tmp/flake" "$tmp/lib" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL past tree (2fe0c687^): gate accepted the mixed files"
  fail=1
else
  echo "ok   past tree (2fe0c687^) fails the gate"
  grep -q 'flake/policies.nix mixes' <<<"$out" \
    && echo "ok   the failure names flake/policies.nix" \
    || { echo "FAIL the failure does not name flake/policies.nix"; fail=1; }
  grep -q 'flake/epistemics.nix mixes' <<<"$out" \
    && echo "ok   the failure names flake/epistemics.nix" \
    || { echo "FAIL the failure does not name flake/epistemics.nix"; fail=1; }
  grep -q 'nix-files.nix mixes' <<<"$out" \
    && { echo "FAIL the gate blames nix-files.nix — it mixes no aliases"; fail=1; } \
    || echo "ok   the honest control file is not blamed"
fi

# 3. A fresh mix introduced into a clean file fails: one minority spelling is
# enough — the gate does not need both to be frequent.
cp "$repo"/lib/docs.nix "$tmp/lib/mixed.nix"
echo 'x = builtins.filter (a: a) [];' >>"$tmp/lib/mixed.nix"
mkdir -p "$tmp/just-mixed" && cp "$tmp/lib/mixed.nix" "$tmp/just-mixed/"
if bash "$gate" "$tmp/just-mixed" >/dev/null 2>&1; then
  echo "FAIL single minority spelling: gate accepted builtins.filter next to lib.filter"
  fail=1
else
  echo "ok   one minority spelling fails the gate"
fi

# 4. The filter|>length rule fires on the converted shape: a line that
# filters and ends in `|> ...length` is lib.count spelled long (the class
# 763eaa83 unified out of lib/).
mkdir -p "$tmp/piped"
cat >"$tmp/piped/seeded.nix" <<'EOF'
{ xs, p }: xs |> builtins.filter p |> builtins.length;
EOF
out="$(bash "$gate" "$tmp/piped" 2>&1)"
if [ "$?" -eq 0 ]; then
  echo "FAIL filter|>length: gate accepted the long spelling of lib.count"
  fail=1
else
  echo "ok   filter|>length fails the gate"
  grep -q 'pipes filter |> length' <<<"$out" \
    && echo "ok   the failure names the rule" \
    || { echo "FAIL the failure does not name the filter|>length rule"; fail=1; }
fi

# 5. Honest controls stay green: `length` inside a filter predicate and
# `|> length` on a non-filter source are not lib.count cases.
mkdir -p "$tmp/controls"
cat >"$tmp/controls/predicate.nix" <<'EOF'
{ xs }: xs |> builtins.filter (n: (n |> builtins.length) > 2);
EOF
cat >"$tmp/controls/plain.nix" <<'EOF'
{ xs }: xs |> builtins.map (x: x + 1) |> builtins.length;
EOF
if bash "$gate" "$tmp/controls" >/dev/null 2>&1; then
  echo "ok   predicate-length and non-filter length pass"
else
  echo "FAIL gate over-fired on honest length uses"
  fail=1
fi

# 6. The catAttrs rule fires on a single-field projection lambda — the class
# pass 5 of the lib sweep unified. Seeded, since the tree carries none.
mkdir -p "$tmp/projected"
cat >"$tmp/projected/seeded.nix" <<'EOF'
{ xs }: xs |> builtins.map (t: t.source);
EOF
out="$(bash "$gate" "$tmp/projected" 2>&1)"
if [ "$?" -eq 0 ]; then
  echo "FAIL field-projection map: gate accepted map (x: x.f)"
  fail=1
else
  echo "ok   field-projection map fails the gate"
  grep -q 'catAttrs' <<<"$out" \
    && echo "ok   the failure names catAttrs" \
    || { echo "FAIL the failure does not name catAttrs"; fail=1; }
fi

# 7. Honest lambdas stay green: a nested path, a computed body, and a
# multi-field attrset are not catAttrs cases.
mkdir -p "$tmp/honest-maps"
cat >"$tmp/honest-maps/controls.nix" <<'EOF'
{
  nested = xs: xs |> builtins.map (t: t.a.b);
  computed = xs: xs |> builtins.map (t: t.a + 1);
  record = xs: xs |> builtins.map (t: {name = t.a; value = t.b;});
}
EOF
if bash "$gate" "$tmp/honest-maps" >/dev/null 2>&1; then
  echo "ok   nested, computed and record maps pass"
else
  echo "FAIL gate over-fired on honest map lambdas"
  fail=1
fi

exit "$fail"
