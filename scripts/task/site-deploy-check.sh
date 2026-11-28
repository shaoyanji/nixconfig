#!/usr/bin/env bash
# site-deploy-check.sh — a deploy publishes a surface this tree builds, or nothing.
#
# `checks:site:copies` treats an absent out-link as fine on purpose: nothing reads
# it in CI, and a copy that is not there cannot mislead a drift gate. A deploy is
# the opposite case. The directory handed to `wrangler pages deploy` *is* the
# product, and `pages-deploy.sh` already waits for it to answer 200 everywhere —
# a yesterday's tree answers 200 everywhere too. So three states have to fail:
# the directory is missing (never built, or deleted), it resolves to a store path
# this tree does not build (built from another branch, another checkout, or
# before the change you are shipping), or it is a plain directory (a hand copy
# that outlives whatever produced it).
#
# A store path that this tree builds *is* byte-identical to it, so the link case
# is a string comparison and needs no walk. The plain-directory case is compared
# file for file, because that is the only way a copy can earn trust.
#
# Usage: site-deploy-check.sh
#   SURFACES="/tmp/matt-site=.#sites.matt-site ..." bash scripts/task/site-deploy-check.sh
#   DIR=/tmp/cv-ats bash scripts/task/site-deploy-check.sh   # attr from the manifest
#
# `DIR` is the deploy-time form and is what `pages-deploy.sh` calls: the attr is
# read from `taskfiles/site-manifest.json` by matching the target whose
# `outputPath` is that directory. A directory no manifest target builds with the
# flake (the console's `dist/`, a hand-built bundle) is not a flake surface and is
# passed through, named, so the caller can see it was not gated.
#
# EXIT
#   0  every surface is this tree's build
#   1  a surface is unbuilt, foreign, or a copy that differs — do not publish it
#   2  cannot tell: an attr does not evaluate, or the arguments are malformed
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2

MANIFEST=${MANIFEST:-taskfiles/site-manifest.json}
SURFACES=${SURFACES:-"/tmp/matt-site=.#sites.matt-site /tmp/cv-ats=.#sites.cv-ats-site /tmp/bountystash-mockup=.#sites.bountystash-mockup"}
DIR=${DIR:-}
EVAL_TIMEOUT=${EVAL_TIMEOUT:-120}

# The attr names the task, so the failure carries the command that fixes it.
fix_for() {
  case $1 in
    sites.matt-site*) echo "task matt:build" ;;
    sites.cv-ats-site*) echo "task dev:site:build:cv-ats" ;;
    sites.bountystash-mockup*) echo "task mockup:build" ;;
    *) echo "nix build --builders \"\" --out-link <dir> .#$1" ;;
  esac
}

# The attr a manifest target builds with this flake, by matching its output path.
attr_for_dir() {
  [ -f "$MANIFEST" ] || return 0
  jq -r --arg dir "$1" '.targets[] | select(.outputPath == $dir) | .buildCommand // empty' \
    "$MANIFEST" 2>/dev/null |
    grep -oE '\.#sites\.[A-Za-z0-9._-]+' |
    sed -n 1p | sed 's/^\.#//'
}

if [ -n "$DIR" ]; then
  # A directory that is not there is never a surface worth publishing, whether or
  # not the manifest names it: a typo in a deploy path must stop before wrangler.
  if [ ! -e "$DIR" ] && [ ! -L "$DIR" ]; then
    echo "FAIL $DIR is missing — nothing to publish"
    exit 1
  fi
  attr=$(attr_for_dir "${DIR%/}")
  if [ -z "$attr" ]; then
    echo "skip $DIR is not a surface this flake builds (no manifest target makes it with .#sites.)"
    exit 0
  fi
  SURFACES="${DIR%/}=$attr"
fi

[ -n "$SURFACES" ] || {
  echo "site-deploy-check: pass SURFACES=DIR=ATTR ... or DIR= (the deploy-time form)" >&2
  exit 2
}

bad=0
ok=0

for pair in $SURFACES; do
  dir=${pair%%=*}
  attr=${pair#*=}
  if [ -z "$dir" ] || [ -z "$attr" ] || [ "$attr" = "$pair" ]; then
    echo "site-deploy-check: '$pair' is not DIR=ATTR" >&2
    exit 2
  fi
  dir=${dir%/}
  # Either spelling is an attr: `#sites.matt-site` and `.\#sites.matt-site` both pass
  # through the shell differently, so the flake prefix is dropped here.
  attr=${attr#.\#}
  attr=${attr#\#}

  want=$(timeout "$EVAL_TIMEOUT" nix eval --raw ".#${attr}.outPath" 2>/dev/null)
  if [ -z "$want" ]; then
    echo "site-deploy-check: .#${attr}.outPath does not evaluate here — cannot tell" >&2
    exit 2
  fi

  # The build this tree makes has to exist to be published. This is the check
  # `site-copies` deliberately does not make: an absent copy is noise there, and
  # an absent artifact at a deploy is the whole failure.
  if [ ! -e "$want" ]; then
    echo "FAIL ${dir} would publish ${attr}, which is not built here (${want} is missing)"
    echo "     fix: $(fix_for "$attr")"
    bad=$((bad + 1))
    continue
  fi

  if [ ! -e "$dir" ] && [ ! -L "$dir" ]; then
    echo "FAIL ${dir} is missing — nothing to publish for ${attr}"
    echo "     fix: $(fix_for "$attr")"
    bad=$((bad + 1))
    continue
  fi

  got=$(readlink -f "$dir" 2>/dev/null)
  if [ -z "$got" ] || [ ! -e "$got" ]; then
    echo "FAIL ${dir} is a link to nothing — the build it named is gone"
    echo "     fix: $(fix_for "$attr")"
    bad=$((bad + 1))
    continue
  fi

  if [ "$got" != "$want" ]; then
    # A plain directory is a copy: it can be right, so it is compared rather
    # than condemned. A store path that differs is a different build, full stop.
    case $got in
      /nix/store/*)
        echo "FAIL ${dir} is another build ($got)"
        echo "     this tree builds $want"
        echo "     fix: $(fix_for "$attr")"
        bad=$((bad + 1))
        ;;
      *)
        if diff -rq "$got" "$want" >/dev/null 2>&1; then
          echo "ok   ${dir} is a plain copy of ${attr}"
          ok=$((ok + 1))
        else
          echo "FAIL ${dir} is a hand copy that differs from ${attr}"
          echo "     fix: $(fix_for "$attr")"
          bad=$((bad + 1))
        fi
        ;;
    esac
    continue
  fi

  echo "ok   ${dir} -> ${want}"
  ok=$((ok + 1))
done

if [ "$bad" -ne 0 ]; then
  echo "site-deploy-check: $bad surface(s) cannot be published — build them first" >&2
  exit 1
fi

echo "site-deploy-check: $ok surface(s) are this tree's build"
exit 0
