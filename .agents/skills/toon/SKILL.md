---
name: toon
description: "Encode/decode JSON to compact TOON for agent memory."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [toon, json, serialization, memory]
    related_skills: []
---

# `toon` — Token-Efficient JSON ↔ TOON Conversion

TOON is a line-oriented, token-cheap serialization of JSON. The old
OpenClaw/Vanta agent stored its structured memories in this format, so the
archive at `~/.hermes/openclaw-archive/` (→ `/Volumes/data/openclaw`) and
any exported mem0 TOON dumps decode with this tool.

## 1. Core conversions

```bash
toon input.json -o output.toon          # JSON -> TOON
toon input.toon --json-indent 2         # TOON -> JSON (pretty)
cat data.json | toon -e --stats         # stdin encode with token stats
toon input.toon -d --no-coerce          # decode, keep strings as strings
toon input.json --delimiter pipe        # custom delimiter
toon -i                                 # interactive TUI explorer
```

## 2. Decoding old OpenClaw memories

The archive's mem0 tier stored TOON documents. To read one today:

```bash
# find TOON payloads in the old agent's data
grep -rl "TOON" ~/.hermes/openclaw-archive/memory/ | head
toon <file>.toon -d --json-indent 2     # -> readable JSON
```

To seed ai-memory with a decoded memory:
```bash
toon <file>.toon -d | ai-memory write-page --path runbooks/<topic> -
```

## 3. When to use TOON today

Use for large, uniform arrays fed to LLMs (logs, tables, lists of records):
30–60% fewer tokens than pretty-printed JSON. Do NOT use for deeply nested,
heterogeneous documents where JSON readability matters more.
