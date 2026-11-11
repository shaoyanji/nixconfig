#!/usr/bin/env bash
# ==============================================================================
# NIX SHELL LINT — the shell inside Nix strings, linted
# ==============================================================================
# Routes `task checks:nix:shell` to scripts/task/nix-shell-lint.py, resolving
# shellcheck the way scripts/task/nix-fmt.sh resolves its tools: PATH first, then
# the nixpkgs pinned in flake.lock, cached as a GC-rooted out-link so a later run
# is milliseconds. Same order on purpose — the gate must judge with the same
# version every time, and it must run on a host that has none installed.
#
# Exit: 0 clean · 1 finding(s) · 2 usage, or shellcheck unresolvable
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig-shellcheck"
PY="$REPO_ROOT/scripts/task/nix-shell-lint.py"

case "${1:-}" in
  -h | --help)
    awk 'NR > 2 { if ($0 ~ /^# =+$/) exit; sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
    exit 0
    ;;
esac

[ -f "$PY" ] || {
  echo "ERROR: missing $PY" >&2
  exit 2
}
command -v python3 >/dev/null 2>&1 || {
  echo "ERROR: python3 not on PATH (needed by nix-shell-lint.py)" >&2
  exit 2
}

resolve_shellcheck() {
  if command -v shellcheck >/dev/null 2>&1; then
    command -v shellcheck
    return 0
  fi
  command -v nix >/dev/null 2>&1 || return 1
  local link="$CACHE_DIR/shellcheck" bin
  # The `shellcheck` derivation has bin/man/doc outputs, so `--out-link`
  # writes `shellcheck-bin` rather than `shellcheck`. Look for both.
  bin="$link"
  [ -x "$bin/bin/shellcheck" ] || bin="$link-bin"
  if [ ! -x "$bin/bin/shellcheck" ]; then
    echo "==> resolving shellcheck from the flake.lock-pinned nixpkgs (once)" >&2
    mkdir -p "$CACHE_DIR"
    # --out-link doubles as the GC root, so the toolchain survives collection.
    # --builders "" keeps a gate from spending remote build budget, and the repo
    # path travels in the environment so no quoting can mangle the expression.
    NIX_SHELL_LINT_REPO="$REPO_ROOT" nix build --impure --out-link "$link" --builders "" \
      --expr 'let f = builtins.getFlake ("path:" + builtins.getEnv "NIX_SHELL_LINT_REPO");
              in f.inputs.nixpkgs.legacyPackages.${builtins.currentSystem}.shellcheck' \
      >/dev/null 2>&1 || return 1
    bin="$link"
    [ -x "$bin/bin/shellcheck" ] || bin="$link-bin"
  fi
  [ -x "$bin/bin/shellcheck" ] || return 1
  printf '%s\n' "$bin/bin/shellcheck"
}

SHELLCHECK="$(resolve_shellcheck || true)"
if [ -z "$SHELLCHECK" ]; then
  # A gate that silently skips is worse than one that fails: say so loudly.
  echo "ERROR: shellcheck could not be resolved (PATH, then the flake.lock pin)." >&2
  exit 2
fi

echo "nix-shell-lint: shellcheck $("$SHELLCHECK" --version | sed -n '2p') from ${SHELLCHECK%/*/*}" >&2
exec python3 "$PY" --shellcheck "$SHELLCHECK" "$@"
