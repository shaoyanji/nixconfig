#!/usr/bin/env bash
# scripts/task/codespace.sh — the gh-codespace operations that cost trial and
# error, written once. Task surface: taskfiles/codespace.yml; procedure and the
# measured traps: .agents/skills/codespace/SKILL.md.
#
# Four things here are not obvious, and each one cost a failed attempt:
#   * `gh codespace ssh` has no -q; the first word after the codespace flag is
#     parsed as a gh flag ("unknown shorthand flag: 'q'"), so the remote command
#     must follow `--`.
#   * `gh codespace cp` failed in both directions, so a file crosses as base64
#     over the ssh channel instead.
#   * a codespace's clone had no git credential helper, so `git push` inside it
#     failed; a commit leaves as a bundle and is pushed from the host that holds
#     the gh auth.
#   * `gh codespace list` reports `Shutdown`, never "Stopped": a poll for the
#     wrong string never terminates.
#
# Every refusal and every failed assertion exits 1, so a caller can gate on it.

set -euo pipefail

# Builtins only: `dirname` is external, and `check` must answer even on a bare
# PATH — a lookup that dies here would report the wrong reason for the failure.
SCRIPT_DIR=${BASH_SOURCE[0]%/*}
[ "$SCRIPT_DIR" != "${BASH_SOURCE[0]}" ] || SCRIPT_DIR=.

CS="${CS:-}"
BRANCH="${BRANCH:-main}"
CSDIR="${CSDIR:-}"
CONFIRM="${CONFIRM:-}"

die() {
  echo "codespace: $*" >&2
  exit 1
}

inventory() { gh cs list --limit 100 --json name,state,repository; }

# CS names a codespace explicitly. Otherwise: one codespace in the account is
# used whatever its state, because `gh cs ssh` starts a shutdown one on demand;
# with several, the single Available one wins and anything else is ambiguous —
# a guess is how the wrong machine gets stopped or reset.
resolve() {
  if [ -n "$CS" ]; then
    printf '%s\n' "$CS"
    return
  fi
  local all total avail n_avail
  all=$(inventory | jq -r '.[].name')
  total=$(printf '%s' "$all" | grep -c . || true)
  if [ "$total" -eq 1 ]; then
    printf '%s\n' "$all"
    return
  fi
  avail=$(inventory | jq -r '[.[] | select(.state == "Available") | .name] | .[]')
  n_avail=$(printf '%s' "$avail" | grep -c . || true)
  case "$n_avail" in
    1) printf '%s\n' "$avail" ;;
    0) die "$total codespaces, none Available — set CS=<name> (task codespace:list)" ;;
    *) die "$n_avail codespaces are Available — set CS=<name> (task codespace:list)" ;;
  esac
}

# Puts a remote command in the checkout. /workspaces/<repo> is the only checkout
# a codespace has, so it is discovered instead of assumed.
cd_fragment() {
  if [ -n "$CSDIR" ]; then
    printf 'cd %q' "$CSDIR"
    return
  fi
  printf '%s' 'd=$(ls -d /workspaces/*/ 2>/dev/null | head -1); [ -n "$d" ] || { echo "no checkout under /workspaces" >&2; exit 1; }; cd "$d"'
}

cmd_list() {
  inventory | jq -r '.[] | [.state, .name, .repository] | @tsv' |
    while IFS=$'\t' read -r state name repo; do
      printf '%-14s %-34s %s\n' "$state" "$name" "$repo"
    done
}

cmd_exec() {
  local remote="$*" c
  [ -n "$remote" ] || die 'usage: task codespace:exec -- "<command>"'
  # Assigned, not inlined: a `die` inside `$(...)` exits the substitution, and
  # the gh call would then run with an empty -c and try to prompt.
  c=$(resolve)
  gh cs ssh -c "$c" -- "$remote"
}

# Is this codespace safe to stop? Dirty tree or commits that exist nowhere else
# are the two ways a stop loses work.
cmd_status() {
  local c body
  c=$(resolve)
  echo "=== $c ==="
  body=$(
    cat <<'EOS'
echo "branch:  $(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD)"
echo "dirty:   $(git status --porcelain | wc -l | tr -d ' ') path(s)"
if git rev-parse -q --verify "origin/$BRANCH" >/dev/null 2>&1; then
  AHEAD=$(git rev-list --count "origin/$BRANCH..HEAD")
  BEHIND=$(git rev-list --count "HEAD..origin/$BRANCH")
  echo "ahead:   $AHEAD commit(s) not on origin/$BRANCH"
  echo "behind:  $BEHIND commit(s) on origin/$BRANCH not here"
else
  AHEAD=0
  echo "ahead:   unknown — origin/$BRANCH is not a local ref"
fi
DIRTY=$(git status --porcelain | wc -l | tr -d ' ')
if [ "$DIRTY" -ne 0 ]; then
  echo "verdict: UNSAFE — $DIRTY uncommitted path(s) would be lost"
  exit 1
fi
if [ "${AHEAD:-0}" -ne 0 ]; then
  echo "verdict: UNSAFE — $AHEAD commit(s) exist only here (task codespace:push)"
  exit 1
fi
echo "verdict: safe to stop"
EOS
  )
  gh cs ssh -c "$c" -- "BRANCH='$BRANCH'; $(cd_fragment); $body"
}

# `gh cs cp` is not usable, so a file crosses base64 over the ssh channel. The
# byte count is asserted on the far side, because a truncated pipe is silent.
cmd_put() {
  local src="${1:-}" dst="${2:-}" c expect body
  [ -f "$src" ] || die "no such file: $src"
  c=$(resolve)
  if [ -z "$dst" ]; then dst="/tmp/$(basename "$src")"; fi
  expect=$(wc -c <"$src" | tr -d ' ')
  body=$(printf 'mkdir -p %q && base64 -d > %q && w=$(wc -c < %q | tr -d " "); if [ "$w" -ne %q ]; then echo "put: wrote $w of %q bytes" >&2; exit 1; fi; echo "put %q: $w bytes"' \
    "$(dirname "$dst")" "$dst" "$dst" "$expect" "$expect" "$dst")
  base64 <"$src" | gh cs ssh -c "$c" -- "$body"
}

cmd_get() {
  local src="${1:-}" dst="${2:-}" c
  [ -n "$src" ] || die "usage: task codespace:get -- <remote-path> [local-path]"
  c=$(resolve)
  if [ -z "$dst" ]; then dst="$(basename "$src")"; fi
  gh cs ssh -c "$c" -- "base64 -w0 $(printf '%q' "$src")" | base64 -d >"$dst"
  echo "get $src: $(wc -c <"$dst" | tr -d ' ') bytes -> $dst"
}

# The codespace cannot push (no credential helper), so its history leaves as a
# bundle and the push happens here, where `gh` already holds the auth. The
# repository is compared first: pushing a codespace's branch into the checkout
# you happen to be standing in is the expensive mistake.
cmd_push() {
  local c tmp c_repo here_repo bundle
  c=$(resolve)
  c_repo=$(inventory | jq -r --arg n "$c" '.[] | select(.name == $n) | .repository')
  here_repo=$(git config --get remote.origin.url | sed -E 's#(.*github\.com[:/])##; s#\.git$##')
  [ "$c_repo" = "$here_repo" ] || die "this checkout is $here_repo, the codespace is $c_repo — push from the matching clone"
  tmp=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT
  bundle="/tmp/codespace-push-$$.bundle"
  gh cs ssh -c "$c" -- "$(cd_fragment); git bundle create -q '$bundle' --all && base64 -w0 '$bundle'; rm -f '$bundle'" >"$tmp/b64"
  base64 -d <"$tmp/b64" >"$tmp/push.bundle"
  git fetch -q "$tmp/push.bundle" "+refs/heads/*:refs/remotes/codespace/*"
  git rev-parse -q --verify "refs/remotes/codespace/$BRANCH" >/dev/null ||
    die "the codespace has no branch $BRANCH (branches: $(git for-each-ref --format='%(refname:lstrip=4)' refs/remotes/codespace | tr '\n' ' '))"
  echo "codespace $BRANCH: $(git log --oneline -1 "refs/remotes/codespace/$BRANCH")"
  git push origin "refs/remotes/codespace/$BRANCH:refs/heads/$BRANCH"
}

# A history rewrite upstream makes an old clone dangerous, not merely stale: it
# still contains the objects that were purged and would restore them on a push.
#
# The body lives in scripts/task/codespace-sync-body.sh so its fetch-failure path
# can be exercised without a codespace; codespace-sync-test.sh runs those bytes.
cmd_sync() {
  local c body
  c=$(resolve)
  body=$(cat "$SCRIPT_DIR/codespace-sync-body.sh")
  gh cs ssh -c "$c" -- "BRANCH='$BRANCH'; FORCE='${FORCE:-}'; $(cd_fragment); $body"
}

cmd_stop() {
  local c state
  c=$(resolve)
  gh cs stop -c "$c" >/dev/null
  for _ in $(seq 1 60); do
    state=$(inventory | jq -r --arg n "$c" '.[] | select(.name == $n) | .state')
    printf '  %-13s %s\n' "$state" "$(date +%H:%M:%S)"
    if [ "$state" = "Shutdown" ]; then
      echo "stopped: $c"
      return 0
    fi
    sleep 5
  done
  die "$c did not reach Shutdown in 300 s (last state: ${state:-unknown})"
}

cmd_delete() {
  local c
  [ "$CONFIRM" = "1" ] || die "delete needs CONFIRM=1 (it destroys the disk, and anything not pushed)"
  c=$(resolve)
  gh cs delete -c "$c" --force
  echo "deleted: $c"
}

# A codespace bills while it is not Shutdown, and the mistake is silent: nothing
# notices one left Available overnight, and the account keeps paying. This is the
# gate that answers "is anything on the clock?". Read-only — it starts, stops and
# resolves nothing — so it is safe in a checks sweep and never spends a build
# minute or a boot of its own.
#
# Exit: 0 every codespace is Shutdown (or there are none) · 1 something is billing
#       · 2 gh is absent or the query failed, i.e. no answer rather than a clean one
cmd_check() {
  local rows total billing state name repo used
  command -v gh >/dev/null 2>&1 || {
    echo "checks:codespace: gh is not on PATH" >&2
    exit 2
  }
  rows=$(gh cs list --limit 100 --json name,state,repository,lastUsedAt 2>/dev/null) || {
    echo "checks:codespace: could not list codespaces (gh auth status?)" >&2
    exit 2
  }
  total=$(printf '%s' "$rows" | jq 'length')
  if [ "$total" -eq 0 ]; then
    echo "no codespaces"
    return 0
  fi
  printf '%-13s %-34s %-30s %s\n' STATE NAME REPOSITORY 'LAST USED'
  printf '%s' "$rows" |
    jq -r '.[] | [.state, .name, .repository, ((.lastUsedAt // "unknown")[0:19])] | @tsv' |
    while IFS=$'\t' read -r state name repo used; do
      printf '%-13s %-34s %-30s %s\n' "$state" "$name" "$repo" "$used"
    done
  billing=$(printf '%s' "$rows" | jq '[.[] | select(.state != "Shutdown")] | length')
  if [ "$billing" -ne 0 ]; then
    echo "billing: $billing of $total not Shutdown — task codespace:stop CS=<name>" >&2
    return 1
  fi
  echo "nothing billing: all $total codespace(s) are Shutdown"
}

case "${1:-}" in
  list) cmd_list ;;
  exec) shift && cmd_exec "$@" ;;
  status) cmd_status ;;
  put) shift && cmd_put "$@" ;;
  get) shift && cmd_get "$@" ;;
  push) cmd_push ;;
  sync) cmd_sync ;;
  stop) cmd_stop ;;
  delete) cmd_delete ;;
  check) cmd_check ;;
  *)
    echo "usage: codespace.sh {list|exec|status|put|get|push|sync|stop|delete|check}" >&2
    exit 1
    ;;
esac
