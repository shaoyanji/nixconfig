#!/usr/bin/env bash
# switch-preflight.sh — the two things that make a local rebuild slow or silently
# wrong, answered BEFORE anything is evaluated. Both cost milliseconds; each one
# otherwise costs a full evaluation cycle (or, for the boot test, a full host build
# plus a QEMU boot).
#
#   1. UNTRACKED FILES. A flake is a git tree: a module or registry file that is
#      untracked does not exist to the evaluator. Nix prints that once, mid-eval,
#      after the work is already spent — and if the file is only *new*, the build
#      succeeds without it and the change silently is not there. Fix is one word:
#      `git add -N <file>`. Only extensions the evaluator actually reads are fatal;
#      anything else is a warning, because a scratch note should not block a switch.
#
#   2. THE BOOT TEST. `task infra:switch:nixos` boots the host in a VM before it
#      switches (policy: a bad stage-1 cannot be diagnosed from outside). That is
#      a full host build plus a QEMU boot — minutes to tens of minutes, and the
#      switch then builds the same closure again. It is the right gate for a change
#      that can reach stage-1, and pure waste for one that cannot: an nginx vhost
#      cannot break the initrd. So the default (`BOOT=auto`) runs it only when the
#      pending diff touches a stage-1 input; BOOT=1 forces it, BOOT=0 skips it.
#
# Stage-1 inputs are decided by file AND by content: a `fileSystems` entry or a
# `boot.*` option can live in any module, so a changed .nix file that mentions one
# counts. The rule only ever errs toward running the boot test.
#
# Usage: switch-preflight.sh [--boot]
#   --boot   also print exactly one line: `BOOT=run reason=…` or `BOOT=skip reason=…`
# Exits 1 when an evaluator-readable file is untracked (the fix is in the message).
set -uo pipefail

show_boot=0
for arg in "$@"; do
  case "$arg" in
    --boot) show_boot=1 ;;
    *)
      echo "usage: switch-preflight.sh [--boot]" >&2
      exit 2
      ;;
  esac
done

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "switch-preflight: not inside a git work tree — a flake paths: input needs one." >&2
  exit 1
}
cd "$repo_root" || exit 1

# --- 1. untracked files ------------------------------------------------------
# .gitignore is respected, so build `result` links and generated trees stay out of
# this. Only what the evaluator reads is fatal.
readable='\.(nix|toml|yaml|yml|json|lock)$'
untracked="$(git ls-files --others --exclude-standard)"
fatal_untracked="$(printf '%s\n' "$untracked" | grep -E "$readable" || true)"
warn_untracked="$(printf '%s\n' "$untracked" | grep -Ev "$readable" | grep -v '^$' || true)"

if [ -n "$warn_untracked" ]; then
  echo "switch-preflight: untracked files (ignored by the flake, harmless here):" >&2
  printf '  %s\n' $warn_untracked >&2
fi

if [ -n "$fatal_untracked" ]; then
  {
    echo "switch-preflight: REFUSED — files the evaluator reads are untracked."
    echo
    printf '  %s\n' $fatal_untracked
    echo
    echo "  A flake is a git tree: these do not exist to nix eval/build yet, so the"
    echo "  rebuild would either fail mid-eval or silently omit them. Stage the"
    echo "  intent (content can stay unstaged) and re-run:"
    echo
    printf '  git add -N %s\n' $fatal_untracked
  } >&2
  exit 1
fi

# --- 2. does the pending change reach stage-1? -------------------------------
if [ "$show_boot" = 0 ]; then
  exit 0
fi

case "${BOOT:-auto}" in
  0)
    echo "BOOT=skip reason=BOOT=0"
    exit 0
    ;;
  1)
    echo "BOOT=run reason=BOOT=1"
    exit 0
    ;;
  auto) ;;
  *)
    echo "switch-preflight: BOOT must be 0, 1 or auto (got '${BOOT}')" >&2
    exit 2
    ;;
esac

# Staged and unstaged both count: a switch evaluates the work tree, and a staged
# file is what most flows leave behind.
changed="$(
  {
    git diff --name-only
    git diff --cached --name-only
  } | sort -u | grep -v '^$' || true
)"

if [ -z "$changed" ]; then
  echo "BOOT=skip reason=no pending change"
  exit 0
fi

# Whole classes of file that only ever matter at boot.
while IFS= read -r file; do
  case "$file" in
    flake/*)
      echo "BOOT=run reason=flake wiring ($file)"
      exit 0
      ;;
    modules/profiles/boot.nix | hosts/*/hardware*.nix | hosts/*/disko.nix | *impermanence*)
      echo "BOOT=run reason=boot input ($file)"
      exit 0
      ;;
  esac
done <<<"$changed"

# And content: a stage-1 option can be declared in any module.
while IFS= read -r file; do
  case "$file" in
    *.nix) ;;
    *) continue ;;
  esac
  [ -f "$file" ] || continue
  # Only the ADDED lines matter — deleting a boot option is not a boot risk in the
  # same way, and the diff keeps this honest about what the switch will contain.
  if git diff -U0 -- "$file" 2>/dev/null | grep -E '^\+[^+]' | grep -qE \
    '(fileSystems|boot\.(loader|initrd|kernel|kernelParams|blacklistedKernelModules|supportedFilesystems|extraModulePackages|tmpOnTmpfs|swraid|zfs|luks|plymouth)|swapDevices|disko|luks|lvm|systemd-boot|grub)'; then
    echo "BOOT=run reason=stage-1 option added in $file"
    exit 0
  fi
done <<<"$changed"

echo "BOOT=skip reason=nothing boot-reachable in $(printf '%s\n' "$changed" | wc -l | tr -d ' ') changed file(s)"
exit 0
