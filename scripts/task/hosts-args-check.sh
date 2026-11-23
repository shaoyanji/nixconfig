#!/usr/bin/env bash
# ==============================================================================
# HOSTS ARGS — host module arguments and host-import ownership
# ==============================================================================
# Two rules over tracked hosts/**.nix, both run by checks:host(s) before an
# evaluation spends a process:
#   1. every binding the module pattern declares is read (deadnix; statix has no
#      unused-binding lint), and an empty pattern is `_` (statix W10, made hard
#      here where the repo-wide pass only prints it);
#   2. a standalone home host imports modules by inventory, never
#      `self.modules`: its list is `hmModules` in flake/host-inventory.nix,
#      resolved by global.hm-inventory-role. NixOS hosts keep self.modules.
#      The files judged are that host's `modules` paths in the registry, not a
#      guess from its name, so `hosts/<name>/configuration.nix` is covered too.
#
# USAGE
#   hosts-args-check.sh [ROOT]   ROOT defaults to this checkout; the fixture
#                                passes a temp tree with its own inventory.toml
#
# EXIT 0 clean; 1 a finding; 2 cannot judge (tools, inventory, or host files).
# ==============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ "$#" -gt 0 ]; then
  ROOT="$(cd "$1" && pwd)" || {
    echo "hosts-args: no such root: $1" >&2
    exit 2
  }
fi
cd "$ROOT" || exit 2

DEADNIX="$(command -v deadnix || true)"
STATIX="$(command -v statix || true)"
YQ="$(command -v yq || true)"
NIX="$(command -v nix || true)"
if [ -z "$DEADNIX" ] || [ -z "$STATIX" ] || [ -z "$YQ" ]; then
  echo "hosts-args: deadnix, statix and yq are required (modules/profiles/base-node.nix installs them); this gate cannot judge without them." >&2
  exit 2
fi
if [ ! -f inventory.toml ]; then
  echo "hosts-args: $ROOT/inventory.toml is missing — cannot tell which hosts are standalone home hosts." >&2
  exit 2
fi

FILES=()
if [ "$#" -gt 0 ]; then
  while IFS= read -r f; do FILES+=("$f"); done < <(find hosts -type f -name '*.nix' -print 2>/dev/null | sort)
else
  while IFS= read -r f; do FILES+=("$f"); done < <(git ls-files -- 'hosts/*.nix' 'hosts/**/*.nix' | sort -u)
fi
if [ "${#FILES[@]}" -eq 0 ]; then
  echo "hosts-args: no .nix files under $ROOT/hosts — nothing was judged." >&2
  exit 2
fi

fail=0

# Rule 2 first: it names the architecture, not a linter's shorthand.
HOME_HOSTS="$(yq -p toml -o json -r '.hosts | to_entries | map(select(.value.kind == "home") | .key) | .[]' inventory.toml 2>/dev/null)" || {
  echo "hosts-args: inventory.toml could not be read — cannot tell which hosts are standalone home hosts." >&2
  exit 2
}
# Home hosts' files come from the composition registry — what the host actually
# imports. One data eval (~0.05 s, no build); without nix or the registry the
# name shape is the map, and either way a host that resolves to nothing is a
# hard stop: skipping it would report clean on a rule that never ran.
HOME_FILES=""
if [ -n "$NIX" ] && [ -f flake/host-inventory.nix ]; then
  HOME_FILES="$("$NIX" eval --impure --json --expr "
    let inv = import \"$ROOT/flake/host-inventory.nix\" { inputs = {}; self = {}; moduleFiles = {}; };
        homes = builtins.filter (n: (inv.\${n}.kind or \"\") == \"home\") (builtins.attrNames inv);
    in map (n: n + \"\t\" + builtins.concatStringsSep \" \" (map toString (inv.\${n}.modules or []))) homes
  " 2>/dev/null | "$YQ" -r '.[]' 2>/dev/null || true)"
fi
for name in $HOME_HOSTS; do
  files="$(awk -F'\t' -v n="$name" '$1 == n {print $2}' <<<"$HOME_FILES")"
  [ -n "$files" ] || files="hosts/$name.nix"
  routed=0
  for f in $files; do
    f="$(realpath --relative-to="$ROOT" "$f" 2>/dev/null || printf '%s' "$f")"
    [ -f "$f" ] || continue
    routed=1
    if grep -n 'self\.modules' "$f"; then
      echo "hosts-args: $f is a standalone home host but imports self.modules — list those modules in its hmModules entry in flake/host-inventory.nix instead." >&2
      fail=1
    fi
  done
  if [ "$routed" -eq 0 ]; then
    echo "hosts-args: home host $name maps to no file under $ROOT/hosts — the self.modules rule did not run on it; name its files in flake/host-inventory.nix." >&2
    exit 2
  fi
done

if ! "$DEADNIX" --fail "${FILES[@]}"; then
  echo "hosts-args: a host file declares a binding it never reads — remove it; if nothing else is read, write _ instead of a pattern." >&2
  fail=1
fi

for f in "${FILES[@]}"; do
  out="$("$STATIX" check "$f" 2>&1)"
  rc=$?
  case "$out" in
    *"[10] Warning:"*)
      printf '%s\n' "$out" >&2
      echo "hosts-args: $f has an empty argument pattern — write _ instead." >&2
      fail=1
      ;;
  esac
  if [ "$rc" -gt 1 ]; then
    printf '%s\n' "$out" >&2
    echo "hosts-args: statix could not check $f (exit $rc)." >&2
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "hosts-args: ${#FILES[@]} host file(s) clean (args used, home hosts inventory-driven)"
  exit 0
fi
exit 1
