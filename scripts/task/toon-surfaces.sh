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
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

python3 - <<'PY'
import re, sys, glob

FILES = ["AGENTS.md", ".agents/README.md", ".agents/SCHEMA.md"] + sorted(
    glob.glob(".agents/skills/*/SKILL.md")
)

# Emitters whose output an agent reads. A flag reference like --json-schema or
# --output-format json is not an emitter.
COMMAND = re.compile(r"^\s*(nix eval|qmd |task )")
EMITTER = re.compile(r"--json(\s|$)")
FALSE_POSITIVES = ("--json-schema", "--json-schema-", "--json-indent", "--output-format json")

findings = []
for path in FILES:
    try:
        raw = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        continue

    # Join continuations so a two-line pipeline is one logical command.
    joined, buf = [], ""
    for line in raw:
        buf += (" " if buf else "") + line.strip()
        if buf.endswith("\\"):
            buf = buf[:-1].rstrip()
            continue
        joined.append(buf)
        buf = ""
    if buf:
        joined.append(buf)

    for line in joined:
        if not COMMAND.match(line):
            continue
        if not EMITTER.search(line):
            continue
        if any(fp in line for fp in FALSE_POSITIVES):
            continue
        if "json-ok:" in line:
            continue
        # A pipe or a redirect means something else consumes it, or it is saved.
        # Match a redirect, not any `>`: `<h>` in a placeholder is not one.
        if "|" in line or re.search(r"\s>\s*\S", line):
            continue
        findings.append(f"{path}: {line.strip()[:110]}")

if findings:
    print("FAIL: these hand JSON to a reader; pipe into `toon -e` or mark `json-ok:`")
    for finding in findings:
        print("  " + finding)
    sys.exit(1)

print(f"PASS: {len(FILES)} agent-facing files emit TOON, not raw JSON.")
PY
