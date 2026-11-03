#!/usr/bin/env bash
# codespace-sync-test.sh — exercise the codespace sync body offline.
#
# The body `task codespace:sync` sends into a codespace has been wrong in the way
# that matters: a failed `git fetch` fell through to `git reset --hard
# origin/$BRANCH`, moved to the STALE ref, and printed "now at <old commit>" with
# exit 0. A sync that could not authenticate reported success, so a caller saw a
# stale commit described as synced.
#
# That failure is remote-only (the clone inside a codespace has no credential
# helper, so https cannot authenticate), which is why the body lives in
# codespace-sync-body.sh: this test runs those exact bytes against local
# repositories shaped like the two states that matter — an unreachable origin and
# a reachable one. No codespace, no gh, no network.
#
# Run: task checks:codespace:sync
# Exit: 0 every case held · 1 at least one did not

set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# CODESPACE_SYNC_BODY points the cases at a different body, which is how this
# test is proved to catch the regression rather than merely agree with the fix:
# run it against a copy with the guard removed and the fetch cases must fail.
BODY="${CODESPACE_SYNC_BODY:-$HERE/codespace-sync-body.sh}"

if [[ ! -f $BODY ]]; then
  echo "missing $BODY" >&2
  exit 1
fi

pass=0
fail=0
ok() { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
bad() {
  printf '  FAIL  %s\n' "$1"
  fail=$((fail + 1))
}
# expect <description> <actual> <wanted>
expect_eq() {
  if [[ $2 == "$3" ]]; then ok "$1"; else bad "$1 (got '$2', wanted '$3')"; fi
}
# contains <description> <haystack> <needle>
contains() {
  if [[ $2 == *"$3"* ]]; then ok "$1"; else bad "$1 (missing '$3')"; fi
}
omits() {
  if [[ $2 == *"$3"* ]]; then bad "$1 (found '$3')"; else ok "$1"; fi
}

# A bare upstream plus two clones: `seed` writes the commits the upstream has,
# `work` is the codespace checkout under test.
fixture() {
  local d=$1
  git init -q --bare -b main "$d/up.git"
  git init -q -b main "$d/seed"
  git -C "$d/seed" config user.email test@example.invalid
  git -C "$d/seed" config user.name test
  git -C "$d/seed" config commit.gpgsign false
  echo one >"$d/seed/a.txt"
  git -C "$d/seed" add -A
  git -C "$d/seed" commit -qm one
  git -C "$d/seed" remote add origin "$d/up.git"
  git -C "$d/seed" push -q origin main
  git clone -q "$d/up.git" "$d/work"
}

# Put a commit on the upstream that `work` does not have, so a reset would be
# visible rather than a no-op.
advance() {
  git -C "$1/seed" commit -q --allow-empty -m two
  git -C "$1/seed" push -q origin main
}

# run_body <dir> [VAR=value ...] — run the shipped body with the cwd and
# environment `cmd_sync` gives it, capturing combined output and the exit code.
# Sets $out and $rc for the caller.
run_body() {
  local d=$1
  shift
  out=$(cd "$d/work" && BRANCH=main env "$@" bash "$BODY" 2>&1)
  rc=$?
}

head_of() { git -C "$1/work" rev-parse --short HEAD; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "codespace sync body: $BODY"
echo

# --- the regression this test exists for -------------------------------------
d="$tmp/unreachable"
fixture "$d"
advance "$d"
before=$(head_of "$d")
stale_origin=$(git -C "$d/work" rev-parse origin/main)
git -C "$d/work" remote set-url origin "$d/does-not-exist.git"
run_body "$d"

expect_eq "unreachable origin exits 1" "$rc" "1"
contains "names the fetch as the failure" "$out" "could not fetch from origin"
contains "says nothing was reset" "$out" "nothing was reset"
contains "names the unchanged HEAD" "$out" "HEAD is unchanged at $before"
omits "prints no success line" "$out" "now at"
expect_eq "HEAD did not move" "$(head_of "$d")" "$before"
expect_eq "the stale origin/main was not trusted" \
  "$(git -C "$d/work" rev-parse origin/main)" "$stale_origin"
echo

# --- a dirty tree is refused before anything is fetched ----------------------
d="$tmp/dirty"
fixture "$d"
advance "$d"
before=$(head_of "$d")
echo dirty >>"$d/work/a.txt"
run_body "$d"

expect_eq "dirty tree exits 1" "$rc" "1"
contains "names the uncommitted paths" "$out" "refusing: 1 uncommitted path(s)"
expect_eq "HEAD did not move" "$(head_of "$d")" "$before"
omits "prints no success line" "$out" "now at"
echo

# --- FORCE discards the dirt, tracked and untracked --------------------------
d="$tmp/force"
fixture "$d"
before=$(head_of "$d")
echo dirty >>"$d/work/a.txt"
echo stray >"$d/work/untracked.txt"
run_body "$d" FORCE=1

expect_eq "FORCE exits 0" "$rc" "0"
contains "reports the previous commit" "$out" "(was $before)"
expect_eq "the tracked edit is gone" "$(git -C "$d/work" status --porcelain | grep -c a.txt || true)" "0"
expect_eq "the untracked file is gone" "$([[ -e $d/work/untracked.txt ]] && echo present || echo absent)" "absent"
echo

# --- the fast-forward it must still perform ----------------------------------
d="$tmp/forward"
fixture "$d"
before=$(head_of "$d")
advance "$d"
run_body "$d"

expect_eq "fast-forward exits 0" "$rc" "0"
expect_eq "HEAD is origin/main" "$(head_of "$d")" "$(git -C "$d/work" rev-parse --short origin/main)"
contains "reports the previous commit" "$out" "(was $before)"
echo

# --- a branch the remote does not have ---------------------------------------
d="$tmp/nobranch"
fixture "$d"
before=$(head_of "$d")
out=$(cd "$d/work" && BRANCH=feature-nope bash "$BODY" 2>&1)
rc=$?

expect_eq "missing branch exits 1" "$rc" "1"
contains "names the missing branch" "$out" "origin/feature-nope does not exist"
expect_eq "HEAD did not move" "$(head_of "$d")" "$before"
echo

printf 'codespace sync: %d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]] || exit 1
