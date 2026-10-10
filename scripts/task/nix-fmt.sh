#!/usr/bin/env bash
# ==============================================================================
# NIX FMT — the single toolchain-resolution path for every Nix format/lint task
# ==============================================================================
# Single source of truth for the repo's Nix toolchain (deadnix, statix,
# alejandra). Every Nix format/lint task routes through here, so no two paths
# can ever use different tool versions:
#
#   task checks:nix:fix     → nix-fmt.sh --fix --all
#   task dev:fmt            → nix-fmt.sh --fix --all
#   task checks:nix:lint    → nix-fmt.sh --check --all --tools deadnix,statix
#   task checks:nix:format  → nix-fmt.sh --check --all --tools alejandra
#   task checks:nix:watch   → nix-fmt.sh --tools deadnix,alejandra
#
# Default tool set is the HARD GATES (deadnix, alejandra) — the ones that make
# the commit fail. statix is advisory in this repo (its W20 repeated-key warning
# fires on the house style, and .githooks/pre-commit never fixes with it), so it
# is never applied unless asked for by name:
#
#   nix-fmt.sh --fix --all --tools deadnix,statix,alejandra   # opt in to statix
#
# checks:nix:lint still *reports* statix findings; nothing is hidden, it is just
# not auto-applied.
#
# Why not `nix-shell -p` per invocation: the watch task runs this on every save,
# so resolving a shell each time would cost seconds per keystroke. The toolchain
# is resolved ONCE from the nixpkgs revision pinned in flake.lock — the same
# versions the pre-commit gate uses — and kept as GC-rooted out-links under
# ~/.cache, so later runs exec the binaries directly in milliseconds.
#
# Resolution order mirrors .githooks/pre-commit exactly (PATH first, then the
# flake.lock pin) so the watcher can never format with different versions than
# the gate that will judge the commit.
#
# Modes:
#   (none)      fix the .nix files git reports as changed (the watch-hook path)
#   --all       every .nix file under flake.nix, flake, hosts, modules,
#               overlays, lib — directories are expanded to their .nix files
#   --fix       same as none, explicit
#   --check     report only, write nothing; exit 1 if a hard gate fails
#   FILE...     restrict to those files (directories are expanded too)
#
# Options:
#   --tools LIST   comma-separated subset of deadnix,statix,alejandra
#                  (default: deadnix,alejandra — the hard gates). Lets
#                  checks:nix:lint keep its exact deadnix+statix gate and
#                  checks:nix:format its alejandra-only gate while both share
#                  this resolver.
#
# Exit: 0 ok · 1 check failed, or fix left residue deadnix/alejandra cannot
#       rewrite (see below) · 2 usage
#
# NOTE — unfixable residue. deadnix refuses to strip the *last* lambda
# argument, so `{pkgs}: …` with an unused `pkgs` is reported by `deadnix --fail`
# but never rewritten by `deadnix --edit`. Fix mode therefore re-verifies and
# exits non-zero rather than reporting success on a tree the commit gate would
# still reject.
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig-nixfmt"
ALL_PATHS=(flake.nix flake hosts modules overlays lib)

show_help() {
  # Print the header block between the two rule lines, so the help can never
  # drift out of sync with the comment above.
  awk 'NR > 2 { if ($0 ~ /^# =+$/) exit; sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
}

MODE="fix"
SCOPE="changed"
TOOLS="deadnix,alejandra"
FILES=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    --fix) MODE="fix" ;;
    --all) SCOPE="all" ;;
    --tools) shift; TOOLS="${1:-}" ;;
    --tools=*) TOOLS="${1#--tools=}" ;;
    -h | --help)
      show_help
      exit 0
      ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) FILES+=("$1"); SCOPE="explicit" ;;
  esac
  shift
done

# --- tool selection ----------------------------------------------------------
want() {
  case ",$TOOLS," in
    *",$1,"*) return 0 ;;
    *) return 1 ;;
  esac
}

if [ -z "$TOOLS" ]; then
  echo "ERROR: --tools needs a value (deadnix,statix,alejandra)." >&2
  exit 2
fi
IFS=',' read -r -a SELECTED <<<"$TOOLS"
for t in "${SELECTED[@]}"; do
  case "$t" in
    deadnix | statix | alejandra) ;;
    *) echo "ERROR: unknown tool '$t' (expected deadnix, statix, alejandra)." >&2; exit 2 ;;
  esac
done

# --- toolchain ---------------------------------------------------------------
# Portable hashing: GNU coreutils on Linux, BSD `shasum` on macOS, openssl last.
# The pre-commit hook calls this script, and the hook runs on macOS too, where
# `sha256sum` does not exist.
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  else
    return 1
  fi
}

# The pinned nixpkgs rev is only needed when a tool is missing from PATH, and
# `nix flake metadata` evaluates the flake, so the answer is cached and keyed on
# flake.lock — re-resolved only when the lock actually changes.
pinned_nixpkgs() {
  local rev_file="$CACHE_DIR/nixpkgs-rev" stamp_file="$CACHE_DIR/flake.lock.sha" lock_sha rev
  mkdir -p "$CACHE_DIR"
  lock_sha="$(sha256_of "$REPO_ROOT/flake.lock" || true)"
  # With no hash tool we cannot tell whether the cached rev is still current, so
  # fall through and re-resolve rather than trusting a stamp we cannot check.
  if [ -n "$lock_sha" ] && [ -s "$rev_file" ] && [ "$(cat "$stamp_file" 2>/dev/null || true)" = "$lock_sha" ]; then
    cat "$rev_file"
    return 0
  fi
  rev="$(nix flake metadata --json "$REPO_ROOT" 2>/dev/null |
    jq -r '.locks.nodes.nixpkgs.locked // empty
           | select(.type == "github")
           | "github:\(.owner)/\(.repo)/\(.rev)"' 2>/dev/null)" || true
  [ -n "$rev" ] || return 1
  printf '%s\n' "$rev" >"$rev_file"
  if [ -n "$lock_sha" ]; then printf '%s\n' "$lock_sha" >"$stamp_file"; fi
  printf '%s\n' "$rev"
}

resolve_tool() {
  local tool="$1" attr="$2" rev link
  if command -v "$tool" >/dev/null 2>&1; then
    command -v "$tool"
    return 0
  fi
  command -v nix >/dev/null 2>&1 || return 1
  rev="$(pinned_nixpkgs)" || return 1
  link="$CACHE_DIR/$tool"
  if [ ! -x "$link/bin/$tool" ]; then
    echo "==> resolving $tool from the flake.lock-pinned nixpkgs (once)" >&2
    # --out-link doubles as the GC root, so the toolchain survives collection.
    nix build "${rev}#${attr}" --out-link "$link" >/dev/null 2>&1 || return 1
  fi
  [ -x "$link/bin/$tool" ] || return 1
  printf '%s\n' "$link/bin/$tool"
}

# Only resolve what was asked for: checks:nix:format must not depend on deadnix
# being resolvable, and vice versa.
DEADNIX=""
STATIX=""
ALEJANDRA=""
if want deadnix; then DEADNIX="$(resolve_tool deadnix deadnix || true)"; fi
if want statix; then STATIX="$(resolve_tool statix statix || true)"; fi
if want alejandra; then ALEJANDRA="$(resolve_tool alejandra alejandra || true)"; fi

# alejandra is the hard formatter gate; statix is advisory in this repo (its W20
# repeated-key warning fires on the house style); deadnix is a hard gate that we
# degrade to a warning when it cannot be resolved, exactly as the pre-commit
# hook does.
if want alejandra && [ -z "$ALEJANDRA" ]; then
  echo "ERROR: alejandra could not be resolved (required by --tools alejandra)." >&2
  exit 1
fi
if want deadnix && [ -z "$DEADNIX" ]; then
  echo "WARNING: deadnix could not be resolved — dead-code check skipped." >&2
fi
# Never report a vacuous pass: if not one requested tool resolved, the gate we
# were asked to run did not actually run.
if [ -z "$DEADNIX" ] && [ -z "$STATIX" ] && [ -z "$ALEJANDRA" ]; then
  echo "ERROR: none of the requested tools ($TOOLS) could be resolved." >&2
  exit 1
fi

# --- target selection --------------------------------------------------------
# Directories are expanded to the .nix files beneath them; the tools recurse
# when handed a directory, but this script iterates file-by-file, so it must do
# the expansion itself. (It once did not, and `--all` silently covered only
# flake.nix while reporting "6 file(s) clean".)
expand_paths() {
  local p
  for p in "$@"; do
    if [ -d "$p" ]; then
      find "$p" -type f -name '*.nix' -print
    elif [ -f "$p" ]; then
      printf '%s\n' "$p"
    fi
  done
}

CANDIDATES=()
if [ "$SCOPE" = "all" ]; then
  CANDIDATES=("${ALL_PATHS[@]}")
elif [ "$SCOPE" = "explicit" ]; then
  CANDIDATES=("${FILES[@]}")
else
  # The watch path: only what git sees as dirty, so a save costs one file.
  while IFS= read -r f; do
    [ -n "$f" ] && CANDIDATES+=("$f")
  done < <(
    {
      git -C "$REPO_ROOT" diff --name-only --diff-filter=ACM -- '*.nix'
      git -C "$REPO_ROOT" diff --cached --name-only --diff-filter=ACM -- '*.nix'
      git -C "$REPO_ROOT" ls-files --others --exclude-standard -- '*.nix'
    } 2>/dev/null
  )
fi

cd "$REPO_ROOT"

FILES=()
if [ "${#CANDIDATES[@]}" -gt 0 ]; then
  while IFS= read -r f; do
    [ -n "$f" ] && FILES+=("$f")
  done < <(expand_paths "${CANDIDATES[@]}" | sort -u)
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  # Nothing to do is the normal steady state of a watcher — stay quiet.
  exit 0
fi

# Check mode runs the tools in BULK, one process each over the whole target set.
# The tools recurse through directories and alejandra threads internally, so
# this is far faster than spawning a process per file (measured over this tree:
# 0.095s vs 1.185s for alejandra) and it is what the original `nix-shell`-based
# tasks did. Nothing here writes, so per-file attribution is not needed.
CHECK_TARGETS=()
if [ "$MODE" = "check" ]; then
  for p in "${CANDIDATES[@]}"; do
    if [ -e "$p" ]; then CHECK_TARGETS+=("$p"); fi
  done
  if [ "${#CHECK_TARGETS[@]}" -eq 0 ]; then
    exit 0
  fi
fi

# --- serialise (fix mode only) -------------------------------------------------
# Fix mode writes, and watch mode fires several events for one logical change
# (create + write + the write this script itself performs), so two runs can
# overlap on the same file: they race on identical writes and each reports a
# change. The lock also makes the loser of the race observe an already-clean
# file and stay quiet. Check mode never writes, so it takes no lock.
if [ "$MODE" = "fix" ]; then
  if command -v flock >/dev/null 2>&1; then
    mkdir -p "$CACHE_DIR"
    exec 9>"$CACHE_DIR/.lock"
    if ! flock -w 30 9; then
      echo "ERROR: another nix-fmt run has held the lock for 30s." >&2
      exit 1
    fi
  else
    # macOS ships no flock. Running unlocked is acceptable here: the watcher is
    # a Linux workflow, and a mkdir-based fallback lock can wedge for the full
    # timeout after a crashed run.
    echo "note: flock unavailable — fix running unlocked" >&2
  fi
fi

# --- run ---------------------------------------------------------------------
if [ "$MODE" = "check" ]; then
  failed=0
  if [ -n "$DEADNIX" ]; then
    if ! "$DEADNIX" --fail "${CHECK_TARGETS[@]}"; then
      echo "deadnix: dead code found in the files listed above" >&2
      failed=1
    fi
  fi
  if [ -n "$STATIX" ]; then
    # One call per target. `statix check` takes a SINGLE target and rejects a
    # second with a usage error (rc=2); passing the whole array here silently
    # did nothing, because the `|| true` below hid it. The loop is what makes
    # that class of mistake impossible.
    #
    # The `|| true` is deliberate, not a swallowed failure: with exactly one
    # target a non-zero exit means "lint findings", and statix is advisory in
    # this repo (its W20 repeated-key warning fires on the house style), so it
    # reports and never sets `failed`.
    for p in "${CHECK_TARGETS[@]}"; do
      "$STATIX" check "$p" || true
    done
  fi
  if [ -n "$ALEJANDRA" ]; then
    if ! "$ALEJANDRA" --check "${CHECK_TARGETS[@]}"; then
      echo "alejandra: the files listed above are not formatted" >&2
      failed=1
    fi
  fi
  [ "$failed" -eq 0 ] && echo "OK: ${#FILES[@]} file(s) clean" || echo "FAIL: Nix checks failed"
  exit "$failed"
fi

fixed=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  # Change detection by comparison rather than by hash: `cmp` is portable (fix
  # mode is reachable from the hook, i.e. macOS, where sha256sum is absent) and
  # equally precise. A no-op run writes nothing, which is what keeps the watch
  # task from re-triggering itself — all three tools are idempotent.
  before_copy="$CACHE_DIR/.before.$$"
  cp "$f" "$before_copy"
  [ -n "$DEADNIX" ] && "$DEADNIX" --edit "$f" >/dev/null 2>&1 || true
  [ -n "$STATIX" ] && "$STATIX" fix "$f" >/dev/null 2>&1 || true
  [ -n "$ALEJANDRA" ] && "$ALEJANDRA" "$f" >/dev/null 2>&1 || true
  if ! cmp -s "$before_copy" "$f"; then
    echo "  formatted: $f"
    fixed=$((fixed + 1))
  fi
  rm -f "$before_copy"
done

[ "$fixed" -gt 0 ] && echo "==> $fixed file(s) formatted" || true

# Re-verify. Fix mode must not claim success on a tree that still fails the
# same hard gates the pre-commit hook enforces.
residual=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  if [ -n "$DEADNIX" ] && ! "$DEADNIX" --fail "$f" >/dev/null 2>&1; then
    echo "  UNFIXABLE dead code in $f (run: deadnix $f)" >&2
    residual=1
  fi
  if [ -n "$ALEJANDRA" ] && ! "$ALEJANDRA" --check "$f" >/dev/null 2>&1; then
    echo "  UNFIXABLE formatting in $f" >&2
    residual=1
  fi
done
if [ "$residual" -eq 1 ]; then
  echo "FAIL: rewrote what the tools can, but the issues above cannot be auto-fixed — needs a human edit." >&2
  exit 1
fi
exit 0
