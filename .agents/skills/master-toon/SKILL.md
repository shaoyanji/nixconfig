---
name: master-toon
description: "Pick me when an agent must read or write structured data: TOON is the IR an agent consumes and emits, JSON links the tools, and TOML/YAML/Nix cross the boundary in the machine's own converter."
version: 0.4.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [toon, json, serialization, memory, context, ledger, ir]
    related_skills: [knowledge-base, fleet-sentinel, ai-memory, task-plane]
---

# master TOON: the IR between machine formats and the agent

TOON is an intermediate representation, not a file format. JSON is the layer that
links everything here: flakes emit it, `jq` filters it, every CLI in the tree
speaks it. TOON is that JSON projected into something an agent reads without
paying for punctuation. It sits where IR sits in a compiler: the layers above
compile into it, the layers below consume it, and nobody hand-edits it.

Three rules follow, and the rest of this skill is mechanics.

1. **Consume TOON, emit TOON.** An agent's eyes and hands are the TOON layer.
2. **Source formats belong to the machine.** TOML, YAML and Nix are truth, and
   their own tooling is the only thing that touches them: `yq`, `tomlkit`,
   `nix eval`, `jq`. Never hand-parse a YAML block you could ask `yq` about, and
   never hand-write a TOML or Nix value you could emit and convert.
3. **Repair only the interface.** The only thing that breaks at this boundary is
   the TOON itself, and it breaks in one way: the `[n]` row count. That is what
   `task dev:toon:fix` is for.

## 1. The boundary, and who crosses it

| Layer | Form | Tool that crosses it | Who reads it |
| :--- | :--- | :--- | :--- |
| Source of truth | TOML (`inventory.toml`, `modules.toml`), YAML (`taskfiles/*.yml`), Nix (`.#inventory`, `.#agentSkills`), JSONL (ledger) | `yq -p toml -o json`, `yq -p yaml -o json`, `nix eval --json`, `jq` | the machine |
| Linking layer | JSON | `toon -e` / `toon -d` | the pipe |
| Agent | TOON | the agent | the agent |

Read a source format through its tool:

```bash
yq -p toml -o json inventory.toml | toon -e
yq -p yaml -o json taskfiles/checks.yml | toon -e
nix eval --json .#inventory.hosts | toon -e
```

Emit in the other direction the same way: write TOON, convert with the tool.
`checks:toon` proves TOON -> JSON -> YAML -> JSON and TOON -> JSON -> TOML ->
JSON both return the same document (the TOML leg uses `inventory.toml`, 34
nested hosts, not a fixture).

```bash
toon -d hosts.toon | yq -p json -o yaml > hosts.yaml
toon -d hosts.toon | yq -p json -o toml > hosts.toml
```

JSON stays wherever a program is the consumer: `| jq`, `> file.json`, a flake
output, an API body. `task checks:toon:surfaces` enforces that split in the 52
agent-facing docs, so a command that emits JSON at a reader fails the gate.

## 2. The `[n]` trap

The `[n]` in `items[12]{id,name}:` is a row count. Counting rows by hand is the
one place this interface breaks, and it breaks loudly: strict decode refuses the
document.

```
$ toon -d miscounted.toon
Error: Failed to decode TOON
Caused by: Parse error at line 4, column 1: Expected 2 tabular rows, but found more
```

Do not count. Repair:

```bash
task dev:toon:fix FILES=miscounted.toon   # decoded loosely, re-encoded, written back
task dev:toon:fix                         # same, on stdin
```

It prints the headers it changed (`declared: items[2]` / `counted: items[3]`),
reports nothing when the file was already correct, and refuses an input that is
not TOON (JSON starting with `{`, or prose that decodes to a bare string)
without touching it: the script exits 1, `task` reports 201. `task checks:toon`
is the gate: it proves an under-count and an over-count are repaired, proves both
refusals stay refusals, round-trips through YAML and TOML, then strict-decodes
every tracked `.toon`.

## 3. When TOON pays

Measured on this repo, 2026-10-20, `toon -e --stats`:

| Payload | JSON | TOON | Delta |
| :--- | ---: | ---: | ---: |
| `task --list-all --json` (430 flat records) | 216,200 B | 183,040 B | 15.3 % smaller |
| `nix eval --json .#inventory.hosts` (34 nested hosts) | 64,276 B | 65,317 B | 1.6 % larger |

Shape decides, not row count. A flat table repeats every key per row in JSON and
declares it once in TOON; a nested record repeats nothing, so TOON's `key:`-per-
line fallback costs more than the braces it replaces.

| Shape | Use TOON? |
| :--- | :--- |
| Flat, uniform rows (ledger events, task lists, one-level records) | yes |
| Nested or heterogeneous records (host inventory, graph projection) | measure with `--stats` first: it can grow |
| A single object | no: nothing repeats |
| Stored on disk | no: TOON is the projection, the source stays TOML/JSON/Markdown |

## 4. Mechanics

```bash
toon input.json -o output.toon          # JSON -> TOON
cat data.json | toon -e --stats         # stdin encode + measured saving
toon input.toon --json-indent 2         # TOON -> JSON (for jq, not for eyes)
toon input.toon -d --no-strict          # decode ignoring a wrong [n]
toon input.json --delimiter tab         # tab instead of comma
toon -i                                 # interactive explorer
```

The CLI is `toon 0.7.x` (`pkgs.llm-agents.toon`), installed fleet-wide. Missing:
`nix run github:numtide/llm-agents.nix#toon -- --help`.

## 5. The fleet-ledger pipeline

`fleet-sentinel` writes append-only JSONL at `/var/lib/fleet-sentinel/ledger.jsonl`,
one uniform object per line: the shape TOON is built for.

```bash
task ops:ledger:toon                 # last 200 events, TOON, token stat
task ops:ledger:toon N=1000          # wider window
task ops:ledger | jq -r 'select(.state=="degraded") | .ts + " " + .reasons'
```

Read the TOON projection, decide, then act on the JSONL source with `jq`. Never
write TOON back as state.

## 6. Failure modes

| Symptom | Cause | Fix |
| :--- | :--- | :--- |
| `Expected N tabular rows, but found more` | hand-counted `[n]` | `task dev:toon:fix FILES=<file>` |
| `starts with '{', which is JSON` | a JSON document handed to the repair tool | `toon -e < file.json` (encode, do not repair) |
| `decodes to a bare value` | prose or a scalar, not a document | nothing to repair; check what produced it |
| Everything is a string after decode | delimiter or quoting drift | `-d --no-coerce`, compare types with `jq` |
| Output larger than the JSON | nested records | keep JSON for the program consumer, TOON for the reader |
| `toon: command not found` in a unit | non-login PATH | absolute store path, or `nix shell` |

## 7. Where to look next

- `.agents/SCHEMA.md`: what may be stored where. TOON is never the source.
- `knowledge-base`: the query ladder, and the sidecar that answers it.
- `fleet-sentinel`: ledger schema and what each event means.

Truth: `modules/config/shells/common-packages.nix` — what installs the tool; this page is the procedure.
