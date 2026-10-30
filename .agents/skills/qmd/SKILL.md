---
name: qmd
description: "Local hybrid search for markdown notes via qmd."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['qmd', 'search', 'markdown', 'notes']
    related_skills: []
---

# qmd — Quick Markdown Search (nix-managed)

Local search engine for Markdown notes, docs, and knowledge bases.
Index once, search fast.

## Where the binary comes from

qmd is packaged through **llm-agents.nix** (upstream: tobi/qmd) and is wired in
`modules/user/ai/default.nix` as `pkgs.llm-agents.qmd` (CUDA explicitly disabled
so ares's `cudaSupport = true` does not drag `cudaPackages` into every closure).
No bun/npm install needed; the session-skill's `bun install -g` route
does NOT apply on these hosts.

**It is not on every host's PATH.** `delphi` carries the agents but not qmd
(measured 2026-10-30), so `command: not found` is not an answer — the tasks
resolve the binary themselves:

```bash
task dev:qmd:docs:refresh   # register + index; resolves qmd, no PATH needed
task checks:qmd:docs        # gate: resolvable, registered, index fresh
```

`scripts/task/qmd-docs-index.sh` is the single resolver: `QMD_BIN`, then PATH,
then the **llm-agents revision pinned in `flake.lock`**, built once into
`~/.cache/nixconfig-qmd/qmd` (GC-rooted, `--builders ""` so resolving a tool
never spends remote build budget). For a bare `qmd` call outside those tasks,
take it from a shell at the same pin — not `nix run …#qmd` at upstream HEAD,
which drifts from the lock:

```bash
nix shell "$(jq -r '.nodes["llm-agents"].locked | "github:\(.owner)/\(.repo)/\(.rev)"' flake.lock)#qmd" \
  -c qmd search "impermanence disko" -c nixconfig
```

## Memory hierarchy (decide by jev before acting)

| Layer | Role | When used |
|-------|------|-----------|
| MEMORY.md | Boot — persists across sessions | Always loaded |
| Vault | Fast working memory — offline, personal | First stop for context |
| qmd wiki | Resource — docs, runbooks, codebase | Concept/location queries |
| mem0 / supermemory | Deep consult — when vault + wiki insufficient | Decided by jev (min-prob 0.8, min-margin 0.15) |

**Search order:** vault → wiki (qmd BM25) → mem0/supermemory (jev-decided) → web.

## BM25 skill search workflow

When unsure which skill to read, search the skills index before guessing:

```bash
qmd search "<skill topic>" -c skills --format json
```

Routes to jev if context is insufficient. Fewer tool calls, always context-rich.

- "search my notes / docs / knowledge base"
- "find related notes"
- "retrieve a markdown document from my collection"
- "search local markdown files"

## Default behavior

- Prefer `qmd search` (BM25 keyword). It is typically instant and is
  the default; embeddings (`qmd embed`) are optional and slower.

## Canonical Collections

The fleet maintains 9 indexed collections across `/Volumes/data`:

| Collection | Target Path | Pattern | Description |
|---|---|---|---|
| `vault` | `/Volumes/data/projects/Obsidian-Git-Sync` | `**/*.md` | Personal Obsidian vault: zettels, schematics, notes, and research |
| `nixconfig` | `/Volumes/data/projects/nixconfig` | `**/*.md` | Nix flake documentation, host architecture, and runbooks |
| `offlinebooks` | `/Volumes/data/books/markdown` | `**/*.md` | Academic papers, textbooks, and technical books |
| `skills` | `/home/devji/.hermes/skills` | `**/*.md` | Hermes and Antigravity agent operational skills |
| `apps` | `/Volumes/data/projects/antigravity-application-workflow/src` | `**/*.{typ,md}` | Job applications, resumes, cover letters, and tracking |
| `german` | `/Volumes/data/german/notes` | `**/*.{md,txt}` | German language study notes, vocabulary, and grammar |
| `recipes` | `/Volumes/data/recipes` | `**/*.{cook,md}` | Cooking recipes, meal ideas, and culinary notes |
| `doc-notes` | `/Volumes/data/documents/notes` | `**/*.md` | Personal document summaries, reference notes, and records |
| `project-docs` | `/Volumes/data/projects` | `**/README.md` | Project architectures and README overviews across repositories |

Register or update documentation collections locally:
```bash
task dev:qmd:refresh        # register and reindex nixconfig + vault
task dev:qmd:vault:refresh  # reindex personal Obsidian vault only
task dev:qmd:docs:refresh   # reindex nixconfig docs only
```

Verify index freshness:
```bash
task checks:qmd:docs        # check nixconfig collection index
task checks:qmd:vault       # check Obsidian vault collection index
```

## Multi-Floor Compute Discipline (Eisen Offload)

Frieren (Fleet Mainframe, 15W quad-core `i5-8250U`, 11.5 GB RAM) must **never** run batch vector embeddings:
- Embedding thousands of chunks on Frieren causes thermal throttling, memory pressure, and I/O lockup.
- Eisen (Compute Workstation, 12-core / 24-thread Xeon, 64 GB RAM, local NVMe) is the dedicated embedding worker.
- **Latency minimization across 3 floors:** To prevent thousands of small-file SQLite and stat round-trips over high-latency NFS:
  1. Frieren updates the lexical BM25 index locally against its direct NVMe/SATA storage (`qmd update`).
  2. The single consolidated `index.sqlite` is rsynced to Eisen's local NVMe cache (`~/.cache/qmd/index.sqlite`).
  3. Eisen executes multi-threaded embedding (`qmd embed`) purely against local NVMe.
  4. The updated `index.sqlite` and model weights are synced back to Frieren.

## Automated Monthly Synchronization (No LLM in the Loop)

The entire sync pipeline is packaged as a hermetic `pkgs.writeShellApplication`
([`modules/scripts/qmd-eisen-embed-sync.nix`](../../../modules/scripts/qmd-eisen-embed-sync.nix))
installed into PATH on Frieren as `qmd-eisen-embed-sync`:

* **Avoids WoL if online:** Probes SSH reachability first; skips WoL if Eisen is already awake.
* **Automated Post-Sync Poweroff:** Cleanly shuts down Eisen (`systemctl poweroff`) if it was woken by WoL for this run.
* **Gaming Guard Protection:** Checks whether an active Steam game is running before powering off, preventing disruption to interactive sessions.
* **Checkable:** Supports `--check` for instant connectivity & prerequisite verification, and `--dry-run` for simulation.

1. **Manual / Operator Trigger:**
```bash
qmd-eisen-embed-sync --check          # preflight check
qmd-eisen-embed-sync --status         # view index & Eisen power state
task dev:qmd:sync:eisen -- --check    # run preflight via Taskfile
task dev:qmd:sync:eisen               # run sync (powers off Eisen if woken by WoL)
task dev:qmd:sync:eisen -- -c apps    # embed single collection
```

2. **Declarative Systemd Timer on Frieren:**
Defined in `hosts/frieren/infra-stack.nix`:
- Package: `${qmdEisenEmbedSync}/bin/qmd-eisen-embed-sync`
- Service: `systemd.services.qmd-eisen-embed-sync`
- Timer: `systemd.timers.qmd-eisen-embed-sync`
- Schedule: Runs monthly on the 1st of each month at `02:00:00` (strictly outside Frieren's `03:00–05:30` nightly backup window).

## Common commands

```bash
qmd search "query" -c vault       # search personal Obsidian vault (fast BM25)
qmd search "query" -c apps        # search job applications & resumes
qmd search "query"                # search across all 9 collections
qmd vsearch "concept" -c apps     # vector similarity search (uses Gemma-300M)
qmd query "how does auth work"    # hybrid search (BM25 + vector + rerank)
qmd get "path/to/file.md"         # read full document
qmd get "#docid"                  # fetch document by ID from search results
qmd status                        # show index health, vector counts, and collections
qmd update                        # re-index changed files locally (fast, BM25)
```

## Models and cache

- **Embedding:** `embeddinggemma-300M-Q8_0.gguf` (319 MB) — used for vector similarity (`qmd vsearch`).
- **Reranking:** `qwen3-reranker-0.6b-q8_0.gguf` (610 MB) — used for multi-candidate reranking.
- **Query Expansion:** `qmd-query-expansion-1.7B-q4_k_m.gguf` (1.28 GB) — used for HyDE query synthesis.
- Cached under `~/.cache/qmd/models/`. Synced from Eisen so queries run locally without WAN downloads.
