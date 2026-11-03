# shellcheck shell=bash
# The body of `task codespace:sync`, sent over `gh cs ssh` into the codespace
# checkout. Not a standalone program: `cmd_sync` prefixes it with BRANCH, FORCE
# and a cd to the checkout, so it runs with the caller's cwd already set.
#
# It lives in a file rather than a heredoc because the failure it has to get right
# is remote-only — a clone with no credential helper cannot fetch over https — and
# a heredoc can only be tested by having a codespace. See
# scripts/task/codespace-sync-test.sh, which runs these exact bytes against local
# repositories.
#
# Strict: a failed fetch must abort the body, not fall through to the reset.
set -euo pipefail
git rev-parse -q --verify "origin/$BRANCH" >/dev/null 2>&1 || {
  echo "origin/$BRANCH does not exist on the remote — nothing to sync to" >&2
  exit 1
}
DIRTY=$(git status --porcelain | wc -l | tr -d ' ')
if [ "$DIRTY" -ne 0 ] && [ "${FORCE:-}" != "1" ]; then
  echo "refusing: $DIRTY uncommitted path(s) — commit, or FORCE=1 to discard them" >&2
  exit 1
fi
BEFORE=$(git rev-parse --short HEAD)
# Every remote-tracking ref, not just $BRANCH: `status` compares against
# origin/$BRANCH, and a fetch of one name leaves the others as stale as the
# clone, which reports an already-pushed commit as "ahead" and refuses a stop
# for no reason.
#
# A fetch that cannot authenticate is the failure this function used to hide: the
# clone inside a codespace has no credential helper, fetch died on the missing
# https username, and the reset below then moved to the STALE origin/$BRANCH and
# printed "now at <old commit>" with exit 0. Nothing is reset until the fetch has
# actually succeeded.
if ! git fetch -q --prune origin; then
  cat >&2 <<'NOTES'
sync failed: could not fetch from origin, so nothing was reset.
Inside a codespace this clone has no credential helper, so an https remote cannot
authenticate — that is the usual cause, and the workaround does not need one:
  host:  git bundle create /tmp/sync.bundle <base>..<branch>
         task codespace:put -- /tmp/sync.bundle /tmp/sync.bundle
  guest: git fetch /tmp/sync.bundle <branch> && git reset --hard FETCH_HEAD
           && git update-ref refs/remotes/origin/<branch> FETCH_HEAD
NOTES
  echo "sync failed: HEAD is unchanged at $BEFORE (origin/$BRANCH not refetched)" >&2
  exit 1
fi
git reset --hard "origin/$BRANCH"
# A hard reset leaves untracked files alone, so a tree dirtied by a stray file
# stayed dirty and the checkout could not clean itself. Only FORCE removes them.
if [ "${FORCE:-}" = "1" ]; then git clean -fdq; fi
echo "now at $(git rev-parse --short HEAD) on $(git rev-parse --abbrev-ref HEAD) (was $BEFORE)"
