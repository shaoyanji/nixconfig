#!/usr/bin/env bash
# Fail when an agent-facing doc hands raw JSON to the reader.
#
# The rule (AGENTS.md, "agent-facing projection"): a command whose output an
# agent reads pipes into `toon -e`. A command whose output a *program* consumes
# (`| jq`, `> file`) is fine and stays JSON.
#
# Scope is the routing surface: AGENTS.md, .agents/README.md, .agents/SCHEMA.md
# and every skill. Backslash continuations are joined first, so a pipeline split
# across two lines is judged as one command.
#
# Exception: `json-ok: <reason>` on the line, for a command that must show JSON
# on purpose (a schema dump, a flag reference).
#
# No interpreter: `awk` joins and judges. The previous version needed `python3`
# on PATH, which made the gate unrunnable on a host without one (delphi,
# 2026-10-22) — the same failure as `checks:docs:links`.
#
# Arguments override the file list (a negative-control fixture); the task calls
# it with none.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [ "$#" -gt 0 ]; then
  mapfile -t files < <(printf '%s\n' "$@")
else
  mapfile -t files < <(printf '%s\n' AGENTS.md .agents/README.md .agents/SCHEMA.md; ls .agents/skills/*/SKILL.md)
fi

# Only files that exist, or awk would abort on a missing skill tree.
present=()
for f in "${files[@]}"; do
  if [ -f "$f" ]; then present+=("$f"); fi
done

failures="$(
  awk '
    # A backslash continuation is one logical command, joined by a single space.
    FNR == 1 && buf != "" { judge(buf); buf = "" }
    {
      line = $0
      sub(/^[ \t]+/, "", line)
      sub(/[ \t]+$/, "", line)
      buf = (buf == "" ? line : buf " " line)
      if (buf ~ /\\$/) {
        sub(/\\$/, "", buf)
        sub(/[ \t]+$/, "", buf)
        next
      }
      judge(buf)
      buf = ""
    }
    END { if (buf != "") judge(buf) }

    function judge(cmd) {
      if (cmd !~ /^[ \t]*(nix eval|qmd |task )/) return
      if (cmd !~ /--json([ \t]|$)/) return
      if (index(cmd, "--json-schema") || index(cmd, "--json-indent")) return
      if (index(cmd, "--output-format json")) return
      if (index(cmd, "json-ok:")) return
      # A pipe or a redirect means something else consumes it, or it is saved.
      # Match a redirect with whitespace around it: `<h>` in a placeholder is not one.
      if (index(cmd, "|")) return
      if (cmd ~ /[ \t]>[ \t]*[^ \t]/) return
      printf "  %s: %s\n", FILENAME, substr(cmd, 1, 110)
      failed = 1
    }
  ' "${present[@]}"
)"

if [ -n "$failures" ]; then
  echo 'FAIL: these hand JSON to a reader; pipe into `toon -e` or mark `json-ok:`'
  printf '%s\n' "$failures"
  exit 1
fi

printf 'PASS: %d agent-facing files emit TOON, not raw JSON.\n' "${#present[@]}"
