#!/usr/bin/env bash
# git-push.sh — push the repo, and never let the secrets submodule veto it.
#
# The failure, reproduced 2026-11-02 with git 2.51 and this exact tree:
#
#   $ git push origin main
#   fatal: src refspec 'main' must name a ref
#   fatal: process for submodule 'modules/secrets' failed
#
# With `submodule.recurse = true`, `git push` asks every submodule whether it can
# push *the superproject's refspec source*. The trace says it plainly:
#
#   cd modules/secrets; GIT_DIR=.git git submodule--helper push-check refs/heads/main origin main
#
# `refs/heads/main` is this repo's branch; the secrets submodule has only
# `master`, so the check fails and the superproject push aborts before sending
# anything. `submodule.<name>.branch` does NOT change it (measured: still
# `refs/heads/main`), and neither does `--recurse-submodules=on-demand` alone —
# the source ref comes from the push refspec, not from the submodule's config.
#
# So the submodule is pushed on its own terms first, and only then the
# superproject, with recursion off. A submodule that cannot push stops the run,
# so a dangling pointer is not a possible outcome. docs/nix-patterns.md.
#
# Usage: git-push.sh [--dry-run] [remote] [branch]
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo"

dry=()
dry_flag=""
if [ "${1:-}" = "--dry-run" ]; then
  dry=(--dry-run)
  dry_flag="(dry run) "
  shift
fi
remote="${1:-origin}"
branch="${2:-$(git rev-parse --abbrev-ref HEAD)}"

# Every submodule with commits its remote does not have gets its own push first.
# A submodule is normally in **detached HEAD**, so `@{u}` is not a thing here
# ("fatal: HEAD does not point to a branch") — the target comes from the remote's
# default branch instead, and HEAD is pushed to it explicitly. The path is read
# from .gitmodules rather than `git submodule status`, which also lists the ones
# with no remote at all.
while read -r path; do
  [ -n "$path" ] || continue
  [ -e "$path/.git" ] || continue
  remote_head="$(git -C "$path" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  [ -n "$remote_head" ] || continue
  target="${remote_head#origin/}"
  ahead="$(git -C "$path" rev-list --count "origin/${target}..HEAD" 2>/dev/null || echo 0)"
  [ "$ahead" -gt 0 ] || continue
  echo "git-push: ${dry_flag}$path has $ahead commit(s) origin/$target lacks — pushing them first"
  git -C "$path" push "${dry[@]}" origin "HEAD:refs/heads/$target"
done < <(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')

# The superproject: recursion off, so the refspec stays ours.
echo "git-push: ${dry_flag}$remote $branch"
git push "${dry[@]}" --no-recurse-submodules "$remote" "$branch"
