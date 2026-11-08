#!/usr/bin/env bash
# modules-edges.sh — the dendritic tree's composition rule, as a 0.6 s gate.
#
# Every file under `modules/` is a named module (`.#modules`, walked by
# lib/nix-files.nix), so a module composes with another by NAME:
# `self.modules."profiles.boot"`, or `moduleFiles."…"` in a chain. A relative
# path still works at eval time, which is why it survives review: nothing fails
# until somebody renames the file.
#
# Two shapes are refusals, and they are the ones the 2026-11 conversion had to
# find by hand across 24 files:
#
#   import ../some/file.nix;         a sibling reached by path, with no argument
#                                    that would justify a load
#   imports = [ … ./x.nix … ]        a list element that is a bare path
#
# Deliberately NOT refusals — these are dependencies, not module edges, and the
# knowledge graph records them either way:
#
#   import ../scripts/x.nix {inherit pkgs;}   a load with arguments
#   builtins.readFile ../config/nu/x.nu       an asset, not Nix
#   src = ../scripts/x.sh;  sopsFile = …      the same, inside a derivation
#   nixpkgs.overlays = [ (import ../../overlays/x.nix) ]   not a module
#
# Text only: no eval, no network. Exit 0 clean, 1 on a violation.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if root="$(git -C "$here" rev-parse --show-toplevel 2>/dev/null)"; then
  cd "$root"
else
  cd "$here/../.."
fi

if git rev-parse --git-dir >/dev/null 2>&1; then
  files="$(git ls-files modules | grep '\.nix$' || true)"
else
  files="$(find modules -name '*.nix' 2>/dev/null)"
fi

violations="$(
  while read -r f; do
    [ -n "$f" ] || continue
    awk -v file="$f" '
      {
        line = $0
        sub(/#.*/, "", line)
        sub(/^[ \t]+/, "", line)
        sub(/[ \t]+$/, "", line)
        if (line == "") next

        if (line ~ /import[ \t]+\.\.?\/[^;{}]*\.nix[ \t]*;/)
          printf "%s:%d: relative import without arguments — name it (self.modules.\"…\")\n", file, NR

        if (line ~ /^\.\.?\/[A-Za-z0-9._\/-]+\.nix$/)
          printf "%s:%d: bare path as an imports element — name the module\n", file, NR
      }
    ' "$f"
  done <<EOF
$files
EOF
)"

if [ -n "$violations" ]; then
  printf '%s\n' "$violations"
  echo >&2
  echo "modules-edges: $(printf '%s\n' "$violations" | wc -l) edge(s) reached by path; a module under modules/ is reached by name (see .#modules)" >&2
  exit 1
fi

echo "modules-edges: $(printf '%s\n' $files | wc -l) module(s), every edge by name"
