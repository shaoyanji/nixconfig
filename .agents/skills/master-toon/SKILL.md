---
name: master-toon
description: "Encode/decode JSON as TOON for cheap agent context: uniform arrays, ledgers, inventories, logs. Includes the fleet-ledger pipeline and when NOT to use it."
version: 0.2.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [toon, json, serialization, memory, context, ledger]
    related_skills: [knowledge-base, fleet-sentinel, ai-memory, task-plane]
---

# master TOON — structured context with fewer tokens

TOON is a line-oriented serialization of JSON. It exists for **one** job: moving
large, uniform records into an agent's context without paying JSON's punctuation
tax on every row. It is not a storage format, not a config format, and not a
substitute for prose.

The binary is packaged (`toon 0.7.x`, `pkgs.llm-agents.toon`) and installed on
the fleet. If it is missing: `nix run github:numtide/llm-agents.nix#toon -- --help`.

## 1. Decide first

| Input shape | Use TOON? | Why |
| :--- | :--- | :--- |
| Array of uniform objects (ledger rows, host records, log events) | **yes** | Every key is repeated once per row in JSON; TOON declares it once. |
| Table you will feed to an LLM once | **yes** | 30–60 % fewer tokens; still greppable line-by-line. |
| Nested, heterogeneous document (a plan, a design note) | **no** | JSON/markdown readability wins; the savings vanish. |
| Source of truth on disk | **no** | Keep JSONL/TOML. TOON is a *projection* for context. |
| A single object | **no** | No repetition to remove. |

Rule of thumb: **≥20 rows sharing a schema** is where TOON pays. Below that,
just print JSON.

## 2. Core conversions

```bash
toon input.json -o output.toon           # JSON -> TOON
toon input.toon --json-indent 2          # TOON -> JSON (pretty)
cat data.json | toon -e --stats          # stdin encode + token stats
toon input.toon -d --no-coerce           # decode, keep strings as strings
toon input.json --delimiter pipe         # custom delimiter
toon -i                                  # interactive explorer
```

Round-trip gate (use it before trusting a pipeline):

```bash
toon x.json -o /tmp/x.toon && toon /tmp/x.toon --json-indent 0 | jq -S . > /tmp/a.json
jq -S . x.json > /tmp/b.json && diff -q /tmp/a.json /tmp/b.json
```

## 3. The fleet-ledger pipeline (the reason this is a pinnacle)

`fleet-sentinel` writes append-only JSONL at `/var/lib/fleet-sentinel/ledger.jsonl`
(one JSON object per line, uniform schema). That is exactly TOON's shape.

```bash
task ops:ledger:toon                 # last 200 events, TOON, token stat
task ops:ledger:toon N=1000          # wider window
task ops:ledger | jq -r 'select(.state=="degraded") | .ts + " " + .reasons'
```

Agent loop: read the TOON projection, decide, then act on the **JSONL** source
with `jq` — never write TOON back as state.

## 4. TOON + memory

- **Episodic memory**: decode old OpenClaw/mem0 dumps, then seed
  `ai-memory write-page` (see the `ai-memory` skill). TOON is the transport, the
  wiki page is the durable artifact.
- **Vault**: if a note is a *table* (fleets, inventories, comparisons) and is
  regenerated, store the generator + JSON, not a hand-maintained markdown table.
- **Do not** commit generated `.toon` files. They are projections; the repo's
  sources are TOML/JSON/Markdown. `.gitignore` treats `*.toon` as scratch.

## 5. Failure modes

| Symptom | Cause | Fix |
| :--- | :--- | :--- |
| Everything is a string after decode | delimiter/quoting drift | `-d --no-coerce` and compare types with `jq` |
| Newlines lost in a field | value contains a literal newline | encode the field as JSON string first, or use `--delimiter` that cannot appear |
| File bigger than the JSON | heterogeneous rows | stop; use JSON |
| `toon: command not found` in a cron/unit | non-login PATH | use the absolute store path or `nix shell` |

## 6. Where to look next

- `.agents/SCHEMA.md` — what may be stored where (TOON never is the source).
- `knowledge-base` skill — query ladder and the episodic/prose split.
- `fleet-sentinel` skill — ledger schema and what each event means.
