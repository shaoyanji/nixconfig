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
for name in $HOME_HOSTS; do
  f="hosts/$name.nix"
  [ -f "$f" ] || continue
  if grep -n 'self\.modules' "$f"; then
    echo "hosts-args: $f is a standalone home host but imports self.modules — list those modules in its hmModules entry in flake/host-inventory.nix instead." >&2
    fail=1
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
