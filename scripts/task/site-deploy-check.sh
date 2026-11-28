#!/usr/bin/env bash
# site-deploy-check.sh — a deploy publishes a surface this tree builds, or nothing.
#
# `checks:site:copies` treats an absent out-link as fine on purpose: nothing reads
# it in CI, and a copy that is not there cannot mislead a drift gate. A deploy is
# the opposite case. The directory handed to a remote *is* the product, and a
# yesterday's tree publishes exactly as successfully as today's — `pages-deploy.sh`
# gets 200 on every path of a stale build, an rsync of last week's `dist/` says
# nothing at all, and a symlink rename has no readiness wait to fail in. So the
# directory has to be proved current before it leaves the machine:
#   * it is missing (never built, or deleted);
#   * it resolves to a store path this tree does not build (built from another
#     branch, another checkout, or before the change being shipped);
#   * it is a plain directory whose files do not match the build (a hand copy that
#     outlives whatever produced it).
#
# A store path this tree builds *is* byte-identical to it, so the link case is a
# string comparison and needs no walk. The plain-directory case is compared file
# for file, because that is the only way a copy can earn trust.
#
# WHY one script for four methods: every publish path here hands a directory to a
# remote — `pages-deploy.sh` for wrangler (including direct callers such as
# `matt:deploy:prod`) and `site-target.sh` for every manifest method (pages,
# symlink, rsync, neocities). One question, one gate: a method cannot be added
# without meeting it, and a deploy cannot reach a remote without passing it.
#
# HOW a surface is judged comes from the target's own `buildCommand`, not a guess:
#   * a flake surface (`.#sites.X`, `.?submodules=1#sites.X`) is compared with that
#     ref's `outPath` — the docs site is only the docs site built under the
#     submodule query the manifest builds it with, so the query is kept;
#   * an in-tree surface the flake does not build (the neocities render) must exist
#     and carry the root `index.html` its push script needs; the upload itself is
#     proved by that script's SHA-1 round trip, not here;
#   * a directory outside this tree (the console's `dist/`) is named as ungated
#     rather than silently passed.
#
# Usage: site-deploy-check.sh
#   SURFACES="/tmp/matt-site=.#sites.matt-site ..." bash scripts/task/site-deploy-check.sh
#   DIR=/tmp/cv-ats bash scripts/task/site-deploy-check.sh    # ref from the manifest, by path
#   TARGET=docs bash scripts/task/site-deploy-check.sh         # path and command from the manifest
#   TARGET=docs DIR=/tmp/proof bash scripts/task/site-deploy-check.sh  # that target, elsewhere
#
# `DIR` is the deploy-time form and is what `pages-deploy.sh` calls; `TARGET` is
# what `site-target.sh` calls, because the target name is the only thing it has
# that survives a manifest that moves an out-link. A directory no manifest target
# builds with the flake (a hand-built bundle) is passed through, named, so the
# caller can see it was not gated.
#
# EXIT
#   0  every surface in scope is this tree's build (or is named as not one)
#   1  a surface is unbuilt, foreign, or a copy that differs — do not publish it
#   2  cannot tell: an attr does not evaluate, or the arguments are malformed
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2
repo=$PWD

MANIFEST=${MANIFEST:-taskfiles/site-manifest.json}
SURFACES=${SURFACES:-"/tmp/matt-site=.#sites.matt-site /tmp/cv-ats=.#sites.cv-ats-site /tmp/bountystash-mockup=.#sites.bountystash-mockup"}
TARGET=${TARGET:-}
DIR=${DIR:-}
EVAL_TIMEOUT=${EVAL_TIMEOUT:-120}

# The attr names the task, so the failure carries the command that fixes it.
fix_for() {
  case $1 in
    *sites.fleet-docs-site*) echo 'nix build --builders "" .?submodules=1#sites.fleet-docs-site' ;;
    *sites.matt-site*) echo "task matt:build" ;;
    *sites.cv-ats-site*) echo "task dev:site:build:cv-ats" ;;
    *sites.bountystash-mockup*) echo "task mockup:build" ;;
    *) echo "task dev:site:build:<target> (see taskfiles/site-manifest.json)" ;;
  esac
}

# The flake ref a build command builds, query and all: `.#sites.matt-site`, or the
# docs site's `.?submodules=1#sites.fleet-docs-site`. Dropping the query would
# compare a deploy with a derivation no manifest target makes.
ref_for_command() {
  printf '%s\n' "$1" | grep -oE '\.[^#[:space:]]*#sites\.[A-Za-z0-9._-]+' | sed -n 1p
}

target_field() {
  jq -r --arg t "$1" --arg f "$2" '.targets[$t][$f] // empty' "$MANIFEST" 2>/dev/null
}

# The ref of whichever manifest target publishes this directory. The path is
# matched as the manifest writes it, so `result` and `/tmp/cv-ats` both land.
ref_for_dir() {
  [ -f "$MANIFEST" ] || return 0
  jq -r --arg dir "$1" '.targets[] | select(.outputPath == $dir) | .buildCommand // empty' "$MANIFEST" 2>/dev/null |
    while IFS= read -r cmd; do ref_for_command "$cmd"; done | sed -n 1p
}

# A manifest path is written the way its build command uses it: `/tmp/matt-site`,
# or `result` beside the flake. Both resolve against the repo, because this script
# always runs from there.
abs_path() {
  case $1 in
    /*) printf '%s\n' "${1%/}" ;;
    *) printf '%s\n' "$repo/${1%/}" ;;
  esac
}

work=()   # DIR=REF pairs; REF `-` means this flake does not build it
notice="" # the manifest's own instruction, when a target named the surface
method="" # its deployMethod, for a message that says which method was about to run
in_tree="" # 1/0 when a target says whether its surface lives in this tree

if [ -n "$TARGET" ]; then
  if [ ! -f "$MANIFEST" ]; then
    echo "site-deploy-check: no manifest at $MANIFEST — cannot resolve '$TARGET'" >&2
    exit 2
  fi
  if ! jq -e --arg t "$TARGET" '.targets[$t]' "$MANIFEST" >/dev/null 2>&1; then
    echo "site-deploy-check: '$TARGET' is not a target in $MANIFEST" >&2
    exit 2
  fi
  method=$(target_field "$TARGET" deployMethod)
  notice=$(target_field "$TARGET" buildCommand)
  out=$(target_field "$TARGET" outputPath)
  # A manifest path without a leading `/` is rendered inside this tree (the
  # neocities site); an absolute one is another checkout's build (the console's
  # dist/). Read from the target, not from the path handed to us, so a proof run
  # at a temp directory still judges the target the way its deploy would.
  case $out in
    /*) in_tree=0 ;;
    "") ;;
    *) in_tree=1 ;;
  esac
  if [ -z "$out" ]; then
    # envs and dragoncourt build in another repository and their own publish task
    # moves the result. Nothing here can be compared with this tree — named, not
    # silently passed.
    echo "skip $TARGET has no outputPath in this tree — its own deploy task owns delivery"
    exit 0
  fi
  # `-` is the honest ref for a surface the flake does not build: `${ref:--}` keeps
  # an empty match from becoming a malformed pair and hiding the real problem.
  ref=$(ref_for_command "$notice" || true)
  work+=("$(abs_path "${DIR:-$out}")=${ref:--}")
elif [ -n "$DIR" ]; then
  ref=$(ref_for_dir "$DIR" || true)
  work+=("$(abs_path "$DIR")=${ref:--}")
else
  for pair in $SURFACES; do
    case $pair in
      *=*) work+=("${pair%%=*}=${pair#*=}") ;;
      *)
        echo "site-deploy-check: '$pair' is not DIR=REF" >&2
        exit 2
        ;;
    esac
  done
fi

[ "${#work[@]}" -gt 0 ] || {
  echo "site-deploy-check: pass SURFACES=DIR=REF ..., DIR= or TARGET=" >&2
  exit 2
}

bad=0
ok=0
ungated=0

for pair in "${work[@]}"; do
  dir=${pair%%=*}
  ref=${pair#*=}
  if [ -z "$dir" ] || [ -z "$ref" ] || [ "$ref" = "$pair" ]; then
    echo "site-deploy-check: '$pair' is not DIR=REF" >&2
    exit 2
  fi
  dir=$(abs_path "$dir")
  label=${dir#"$repo"/}
  if [ "$ref" = "-" ]; then
    fix=${notice:-}
  else
    fix=${notice:-$(fix_for "$ref")}
  fi

  # Missing is the whole failure for every method: there is nothing to publish. The
  # old attrs still come in with a leading `.#`, so either spelling is accepted.
  if [ ! -e "$dir" ] && [ ! -L "$dir" ]; then
    echo "FAIL ${label} is missing — nothing to publish${ref:+${method:+ ($method)}}"
    [ -n "$fix" ] && echo "     fix: $fix"
    bad=$((bad + 1))
    continue
  fi

  # Not a flake surface: the tree either renders it here (neocities) or does not
  # own it at all (the console's dist/ in another checkout).
  if [ "$ref" = "-" ]; then
    case ${in_tree:-} in
      1) owned=1 ;;
      0) owned=0 ;;
      *)
        case $dir in
          "$repo"/*) owned=1 ;;
          *) owned=0 ;;
        esac
        ;;
    esac
    if [ "$owned" = 1 ]; then
      if [ -f "$dir/index.html" ]; then
        echo "ok   ${label} is an in-tree surface with a root index.html (${method:-manifest} deploy) — its push script proves the upload"
        ok=$((ok + 1))
      else
        echo "FAIL ${label} has no index.html — a static remote needs a root page"
        [ -n "$fix" ] && echo "     fix: $fix"
        bad=$((bad + 1))
      fi
    else
      echo "skip ${dir} is outside this tree, and no manifest target builds it with this flake — not gated"
      ungated=$((ungated + 1))
    fi
    continue
  fi

  # Either spelling is a ref: `.sites.matt-site` from a SURFACES attr, or a full
  # `.?submodules=1#sites.fleet-docs-site` read back from a build command.
  case $ref in
    .*) eval_ref=$ref ;;
    *) eval_ref=".#${ref}" ;;
  esac

  want=$(timeout "$EVAL_TIMEOUT" nix eval --raw "${eval_ref}.outPath" 2>/dev/null)
  if [ -z "$want" ]; then
    echo "site-deploy-check: ${eval_ref}.outPath does not evaluate here — cannot tell" >&2
    exit 2
  fi

  # The build this tree makes has to exist to be published. This is the check
  # `site-copies` deliberately does not make: an absent copy is noise there, and
  # an absent artifact at a deploy is the whole failure.
  if [ ! -e "$want" ]; then
    echo "FAIL ${label} would publish ${ref}, which is not built here (${want} is missing)"
    [ -n "$fix" ] && echo "     fix: $fix"
    bad=$((bad + 1))
    continue
  fi

  got=$(readlink -f "$dir" 2>/dev/null)
  if [ -z "$got" ] || [ ! -e "$got" ]; then
    echo "FAIL ${label} is a link to nothing — the build it named is gone"
    [ -n "$fix" ] && echo "     fix: $fix"
    bad=$((bad + 1))
    continue
  fi

  if [ "$got" != "$want" ]; then
    # A plain directory is a copy: it can be right, so it is compared rather
    # than condemned. A store path that differs is a different build, full stop.
    case $got in
      /nix/store/*)
        echo "FAIL ${label} is another build ($got)"
        echo "     this tree builds $want"
        echo "     fix: $fix"
        bad=$((bad + 1))
        ;;
      *)
        if diff -rq "$got" "$want" >/dev/null 2>&1; then
          echo "ok   ${label} is a plain copy of ${ref}"
          ok=$((ok + 1))
        else
          echo "FAIL ${label} is a hand copy that differs from ${ref}"
          echo "     fix: $fix"
          bad=$((bad + 1))
        fi
        ;;
    esac
    continue
  fi

  echo "ok   ${label} -> ${want}"
  ok=$((ok + 1))
done

if [ "$bad" -ne 0 ]; then
  echo "site-deploy-check: $bad surface(s) cannot be published — build them first" >&2
  exit 1
fi

if [ "$ok" -eq 0 ]; then
  echo "site-deploy-check: no surface this flake builds is in scope ($ungated named as ungated)"
  exit 0
fi

echo "site-deploy-check: $ok surface(s) are this tree's build"
exit 0
