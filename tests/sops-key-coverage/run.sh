#!/usr/bin/env bash
# Regression fixture for the sops key-coverage assertion in
# modules/global/sops-key-coverage.nix.
#
# The mistake is lumi's 2026-11-28 near-miss: modules/secrets.yaml loses
# morrow-telegram while hosts/lumi.nix still declares sops.secrets."morrow-telegram".
# sops-nix would only notice inside the activation manifest, which eval mode
# never forces; the assertion must refuse the host eval first. A scratch
# worktree gets exactly that deletion. The check reads key names only — nothing
# is decrypted.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd -P)"
cd "$repo" || exit 2

command -v git >/dev/null && command -v yq >/dev/null ||
  { echo "fixture: need git and yq" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'git -C "$repo" worktree remove --force "$tmp/wt" 2>/dev/null; rm -rf "$tmp"' EXIT

git -C "$repo" worktree add --detach "$tmp/wt" HEAD >/dev/null 2>&1 ||
  { echo "fixture: cannot add worktree" >&2; exit 2; }

# host-check-sweep asks Nix for ?submodules=1. A worktree starts with empty
# submodule directories, so give Nix real git repositories at the pinned commits
# by cloning the already-initialized local submodules.
seed_submodule() {
  path="$1"
  sha=$(git -C "$repo" ls-tree HEAD "$path" | awk '$2 == "commit" {print $3}')
  [ -n "$sha" ] || { echo "fixture: $path is not a submodule at HEAD" >&2; return 1; }
  git -C "$repo/$path" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    { echo "fixture: $path is not initialized" >&2; return 1; }
  rm -rf "$tmp/wt/$path"
  git clone -q "$repo/$path" "$tmp/wt/$path" &&
    git -C "$tmp/wt/$path" checkout -q "$sha"
}
seed_submodule modules/secrets || exit 2
seed_submodule projects/neocities-dragoncourt || exit 2

# Exercise the checkout, not only the last commit: when the gate and this
# fixture land together, HEAD does not have the gate yet. Applying the checkout
# diff keeps the pre-commit proof honest; on a clean checkout it is a no-op.
if ! git -C "$repo" diff --quiet HEAD --; then
  git -C "$repo" diff --binary HEAD | git -C "$tmp/wt" apply --index ||
    { echo "fixture: cannot apply the checkout diff" >&2; exit 2; }
fi

fail=0

# 1. The seeded deleted key must fail the lumi host eval, named in the refusal.
yq -i 'del(."morrow-telegram")' "$tmp/wt/modules/secrets.yaml" ||
  { echo "fixture: cannot seed the deleted key" >&2; exit 2; }
out=$(cd "$tmp/wt" && bash scripts/task/host-check-sweep.sh --hosts lumi --mode eval --timeout 240 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'sops key coverage failed' &&
   echo "$out" | grep -q 'morrow-telegram'; then
  echo "ok   seeded deleted key refused, key named"
else
  echo "FAIL seeded tree: rc=$rc — expected a key-coverage refusal"; echo "$out" | tail -10
  fail=1
fi

# 2. The live tree passes the same host gate.
if (cd "$repo" && bash scripts/task/host-check-sweep.sh --hosts lumi --mode eval --timeout 240 >/dev/null 2>&1); then
  echo "ok   HEAD lumi passes"
else
  echo "FAIL HEAD: host gate refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "sops-key-coverage:test: all cases pass"
exit $fail
