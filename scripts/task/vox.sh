#!/usr/bin/env bash
# vox.sh — the vox CLI with the fleet's three backends resolved.
#
# Every backend is optional and every absence is reported, not fatal: no needle3
# engine means the caller has to be a replay fixture, no jev-decide means routing
# falls back to the caller's own pick, and no cpg means the tool answer comes back
# without prose. `vox doctor` is what says which of the three is missing, so this
# script only has to find them.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

# The shipped engine is linux-arm64. Discovery is by store path rather than by an
# exported variable so a host that never set one still works; on x86_64 both stay
# empty and vox says so (the `*-needle-[0-9]*` glob is deliberately not used: it
# matched a leftover needle-2 once and made a stale build look current).
if [ -z "${NEEDLE_ENGINE:-}" ]; then
  NEEDLE_ENGINE=$(ls -d /nix/store/*needle-3/bin/needle 2>/dev/null | tail -1 || true)
fi
if [ -z "${NEEDLE_WEIGHTS:-}" ]; then
  NEEDLE_WEIGHTS=$(ls /nix/store/*-needle3.cact 2>/dev/null | tail -1 || true)
fi
export NEEDLE_ENGINE NEEDLE_WEIGHTS

# One manifest for the fleet: the compiled inventory fields and the two lookups a
# question can name. A caller-specific surface belongs in a file someone reviews,
# not in an environment variable.
if [ -z "${VOX_TOOLS:-}" ]; then
  export VOX_TOOLS="$root/scripts/task/vox-tools.json"
fi
# The battery is a measurement of that surface, not a second surface: shipping it
# beside the manifest is what stops a case from naming a tool the fleet lacks.
if [ -z "${VOX_BATTERY:-}" ]; then
  export VOX_BATTERY="$root/scripts/task/vox-battery.json"
fi

# The `doc_pages` tool shells out to `qmd`, and this host carries the agents but
# not the indexer, so the tool failed with `qmd: executable file not found` while
# the caller's pick was right. Resolve it from `.#cli.search.qmd` — llm-agents'
# qmd, substituted from cache.numtide.com — into the cache link
# qmd-docs-index.sh already shares, and prepend its bin to PATH for the call. A
# miss stays non-fatal: vox reports the failed tool and the turn still answers.
if ! command -v qmd >/dev/null 2>&1; then
  qmd_root="${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig-qmd"
  qmd_bin="$qmd_root/qmd/bin/qmd"
  if [ ! -x "$qmd_bin" ]; then
    qmd_out=$(nix build --no-link --print-out-paths --builders "" "git+file://$root?submodules=1#cli.search.qmd" 2>/dev/null | tail -1 || true)
    if [ -n "$qmd_out" ]; then
      mkdir -p "$qmd_root"
      ln -sfn "$qmd_out" "$qmd_root/qmd"
    fi
  fi
  if [ -x "$qmd_bin" ]; then
    PATH="$(dirname "$qmd_bin"):$PATH"
    export PATH
  fi
fi

bin=${VOX_BIN:-}
if [ -z "$bin" ]; then
  bin=$(command -v vox || true)
fi
if [ -z "$bin" ]; then
  # Not on PATH: build this tree's own package. Cached after the first call, and
  # `--no-link` keeps it out of ./result and out of the profile.
  # git+file, not `path:` — a path URL refuses the `submodules` parameter, and
  # this flake carries submodules, so `path:` is the form that fails.
  out=$(nix build --no-link --print-out-paths "git+file://$root?submodules=1#cli.ai.vox" 2>/dev/null | tail -1)
  if [ -z "$out" ]; then
    echo "vox: no vox on PATH and the package did not build (nix build .#cli.ai.vox)" >&2
    exit 1
  fi
  bin="$out/bin/vox"
fi
# TOON is the projection an agent reads; JSON is the wire form the CLI emits
# ([[flake/policies.nix#agent-boundary-is-toon]]: a program gets JSON, a reader
# gets TOON). `FORMAT=json` asks for the wire form back. Only `ask` and
# `battery` have a JSON mode — every other subcommand already prints prose.
#
# `toon` is resolved from PATH because that is where llm-agents puts it
# (modules/profiles/operator-tools.nix, substituted from cache.numtide.com); a
# missing one is reported and the JSON printed rather than failing the turn.
format=${VOX_FORMAT:-toon}
case "$format" in
  toon | json) ;;
  *)
    echo "vox: unknown FORMAT '$format' (toon or json)" >&2
    exit 1
    ;;
esac
# Only these two subcommands speak JSON, so only they can be projected; every
# other one already prints prose a person reads and has nothing to convert.
speaks_json=no
case "${1:-}" in
  ask | battery) speaks_json=yes ;;
esac
project=no
if [ "$speaks_json" = yes ]; then
  # `-json` may already be among the arguments; appending it twice is harmless
  # but a second copy in a log is noise.
  already=no
  for a in "$@"; do
    if [ "$a" = "-json" ]; then already=yes; fi
  done
  if [ "$already" = no ]; then
    # Before the positional argument, never after: Go's flag parser stops at the
    # first non-flag argument, so `ask <prompt> -json` would silently drop it.
    sub=$1
    shift
    set -- "$sub" -json "$@"
  fi
  if [ "$format" = toon ]; then
    project=yes
  fi
fi

# The contract is the exit code: 0 answered or acted, 2 a proposal that needs a
# person, 3 refused, 4 escalated to a reasoning model. Spelled out rather than
# passed through with `exec`, so an unexpected code cannot leak out as one of
# those four — and so the gate that compares a summary's promise to what the
# script emits has the literals to compare.
set +e
if [ "$project" = yes ]; then
  raw=$(mktemp)
  "$bin" "$@" >"$raw"
  rc=$?
  if [ -s "$raw" ]; then
    if command -v toon >/dev/null 2>&1; then
      toon -e <"$raw" || cat "$raw"
    else
      echo "vox: toon is not on PATH (llm-agents toon, see modules/profiles/operator-tools.nix); printing JSON" >&2
      cat "$raw"
    fi
  fi
  rm -f "$raw"
else
  "$bin" "$@"
  rc=$?
fi
set -e
case "$rc" in
  0) exit 0 ;;
  2) exit 2 ;;
  3) exit 3 ;;
  4) exit 4 ;;
  *) exit 1 ;;
esac
