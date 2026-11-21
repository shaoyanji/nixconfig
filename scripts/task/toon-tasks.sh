#!/usr/bin/env bash
# toon-tasks.sh — gate for the taskfile half of the agent data boundary.
#
# The rule (master-toon, scripts/task/toon-io.sh): a task that hands JSON to a
# reader pipes it through `toon_emit`, not an ad-hoc `| toon -e` or an inline
# `case FORMAT`. A raw `toon -e` stays legal only where the command itself is
# the encoder demo (`toon -e --stats`) or inside toon-io.sh. Only cmds blocks
# are scanned — desc and summary may name the mechanism.
set -euo pipefail
cd "$(dirname "$0")/../.."

fail=0
err() { printf 'toon-tasks: %s\n' "$*" >&2; fail=1; }

python3 - <<'PY' || fail=1
import re, pathlib, sys
bad = []
for p in pathlib.Path('taskfiles').glob('*.yml'):
    lines = p.read_text().split('\n')
    i = 0
    while i < len(lines):
        line = lines[i]
        # A cmds entry: "- |" block or a single "- <cmd>" line.
        if re.match(r'^[ \t]+- \|', line):
            indent = len(line) - len(line.lstrip()); j = i + 1; block = []
            while j < len(lines):
                l = lines[j]
                if l.strip() and (len(l) - len(l.lstrip())) <= indent:
                    break
                block.append((j + 1, l)); j += 1
        elif re.match(r'^[ \t]+- \S', line):
            indent = len(line) - len(line.lstrip()); j = i + 1; block = [(i + 1, line)]
        else:
            i += 1; continue
        body = '\n'.join(l for _, l in block)
        for n, l in block:
            if 'toon -e' in l and 'toon -e --stats' not in l:
                bad.append(f'{p}:{n} emits `toon -e` directly — pipe through toon_emit (scripts/task/toon-io.sh)')
            if re.search(r'case ("?\{\{\.FORMAT\}\}"?|"\$FORMAT") in', l):
                bad.append(f'{p}:{n} hand-cases FORMAT — use toon_emit')
        if 'toon_emit' in body and 'toon-io.sh' not in body:
            n = next(n for n, l in block if 'toon_emit' in l)
            bad.append(f'{p}:{n} calls toon_emit without sourcing toon-io.sh')
        i = j
if bad:
    print(*bad, sep='\n', file=sys.stderr)
    sys.exit(1)
PY

# The library stays sourced the way the tasks spell it.
if ! grep -q 'toon_emit()' scripts/task/toon-io.sh ||
  ! grep -q 'toon_ingest()' scripts/task/toon-io.sh; then
  err 'scripts/task/toon-io.sh lost an entry point'
fi

if [ "$fail" -eq 0 ]; then
  printf 'toon-tasks: clean — every emitter is on the toon_emit contract\n'
fi
exit "$fail"
