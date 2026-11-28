#!/usr/bin/env bash
# site-copies-check.sh — a copy of a site is evidence only if this tree built it.
#
# The CV gates read copies, not the tree: `cv-links-check.sh` hashes the live
# CVs against `/tmp/matt-site`, `cv-blog-check.sh` hashes the blog's copies
# against the same artifact, and `cv-ats-check.sh --deployed` compares the
# published audit with `/tmp/cv-ats`. Those out-links outlive a checkout, a flake
# change and a week of work, so a stale copy makes a green gate prove yesterday:
# the live site matches the copy, and the copy matches nothing in this tree. The
# ATS artifact is worse, since only a hand step writes it.
#
# Each present copy is compared with what the flake evaluates to now, before any
# drift gate reads it. An absent copy is not stale: nothing reads it, and CI has
# no out-links.
#
# Usage: site-copies-check.sh [COPY=ATTR ...]
#   COPIES="/tmp/cv-ats=.#sites.cv-ats-site" bash scripts/task/site-copies-check.sh
#
# EXIT
#   0  every present copy is this tree's build
#   1  a copy is a different build — stale, or built from another tree
#   2  cannot tell: a copy does not resolve, or the eval failed
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2

COPIES=${COPIES:-"/tmp/matt-site=.#sites.matt-site /tmp/cv-ats=.#sites.cv-ats-site"}
EVAL_TIMEOUT=${EVAL_TIMEOUT:-120}

# The attr names the task, so a copy at any path gets the right instruction.
fix_for() {
  case $1 in
    *sites.matt-site*) echo "task matt:build" ;;
    *sites.cv-ats-site*) echo "task dev:site:build:cv-ats" ;;
    *) echo "rebuild the out-link with the task that writes it" ;;
  esac
}

present=0
absent=0
stale=0

for pair in $COPIES; do
  copy=${pair%%=*}
  attr=${pair#*=}
  if [ -z "$copy" ] || [ -z "$attr" ] || [ "$attr" = "$pair" ]; then
    echo "site-copies: '$pair' is not COPY=ATTR" >&2
    exit 2
  fi
  # -L as well as -e: a dangling out-link is a copy that is present and broken,
  # and `-e` alone follows it to nothing and calls it absent.
  if [ ! -L "$copy" ] && [ ! -e "$copy" ]; then
    absent=$((absent + 1))
    continue
  fi
  present=$((present + 1))

  target=$(readlink -f "$copy" 2>/dev/null)
  if [ -z "$target" ] || [ ! -e "$target" ]; then
    echo "site-copies: $copy is present but does not resolve to a tree" >&2
    echo "site-copies: remove it and run $(fix_for "$attr")" >&2
    exit 2
  fi

  err=$(mktemp)
  built=$(timeout "$EVAL_TIMEOUT" nix eval --raw "$attr.outPath" 2>"$err")
  rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$built" ]; then
    sed 's/^/  /' "$err" >&2
    rm -f "$err"
    echo "site-copies: could not evaluate $attr.outPath (rc=$rc)" >&2
    exit 2
  fi
  rm -f "$err"

  if [ "$target" = "$built" ]; then
    echo "ok   $copy is this tree's build"
    continue
  fi

  stale=$((stale + 1))
  echo "FAIL $copy is not this tree's build"
  echo "     copy: $target"
  echo "     tree: $built"
  echo "     fix:  $(fix_for "$attr")"
done

if [ "$stale" -ne 0 ]; then
  echo "site-copies: $stale of $present present copy(ies) are stale — a drift gate would compare against the wrong build"
  exit 1
fi

if [ "$present" -eq 0 ]; then
  echo "site-copies: no out-link present, nothing to check ($absent looked for)"
  exit 0
fi

echo "site-copies: $present present copy(ies) are this tree's build ($absent absent)"
