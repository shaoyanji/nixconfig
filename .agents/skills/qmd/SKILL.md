---
name: qmd
description: Local hybrid search for markdown notes and docs via the qmd CLI (nix-managed, pkgs.llm-agents.qmd). Use when searching notes, finding related content, or retrieving documents from indexed collections.
homepage: https://github.com/tobi/qmd
---

# qmd — Quick Markdown Search (nix-managed)

Local search engine for Markdown notes, docs, and knowledge bases.
Index once, search fast.

## Where the binary comes from

qmd is packaged through **llm-agents.nix** (upstream: tobi/qmd) and is
already installed fleet-wide — it is in `modules/user/ai/default.nix`
as `pkgs.llm-agents.qmd` (CUDA explicitly disabled so ares's
`cudaSupport = true` does not drag `cudaPackages` into every closure).
No bun/npm install needed; the session-skill's `bun install -g` route
does NOT apply on these hosts.

```bash
nix build .#nixosConfigurations.<host>.pkgs.llm-agents.qmd   # build/refetch
command -v qmd                                               # present on hosts
```

## When to use (trigger phrases)

- "search my notes / docs / knowledge base"
- "find related notes"
- "retrieve a markdown document from my collection"
- "search local markdown files"

## Default behavior

- Prefer `qmd search` (BM25 keyword). It is typically instant and is
  the default; embeddings (`qmd embed`) are optional and slower.

## Canonical Collections

The fleet maintains two primary collections:

| Collection | Target Path | Description |
|---|---|---|
| `vault` | `/Volumes/data/Obsidian-Git-Sync` (`~/vaults/personal`) | Personal Obsidian vault: zettels, schematics, notes, and research. |
| `nixconfig` | `/Volumes/data/projects/nixconfig` (`~/Documents/nixconfig`) | Nix flake documentation, host architecture, and runbooks. |

Register or update both collections automatically:
```bash
task dev:qmd:refresh        # register and reindex both collections
task dev:qmd:vault:refresh  # reindex personal Obsidian vault only
task dev:qmd:docs:refresh   # reindex nixconfig docs only
```

Verify index freshness:
```bash
task checks:qmd:docs        # check nixconfig collection index
task checks:qmd:vault       # check Obsidian vault collection index
```

## Common commands

```bash
qmd search "query" -c vault       # search personal Obsidian vault (zettels/notes)
qmd search "query" -c nixconfig   # search nixconfig documentation
qmd search "query"                # search across all collections
qmd search "query" -n 10          # return top 10 results
qmd search "query" --json         # agent-friendly JSON output
qmd get "path/to/file.md"         # read full document
qmd get "#docid"                  # fetch document by ID from search results
qmd status                        # show index health and file counts
qmd update                        # re-index changed files (fast, BM25)
qmd embed                         # compute embeddings for semantic vector search
```

## Keeping the index fresh

`qmd update` is enough for BM25 freshness; run it after editing notes or on a schedule.
`task dev:qmd:refresh` ensures both collections are tracked and up to date.

## Models and cache

Local GGUF models auto-download on first embedding run.
Default cache: `~/.cache/qmd/models/` (override with `XDG_CACHE_HOME`).
