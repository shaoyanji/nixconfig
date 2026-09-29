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

## Setup

```bash
qmd collection add /path/to/notes --name notes --mask "**/*.md"
qmd context add qmd://notes "Description of this collection"  # optional
```

## What it indexes

- Markdown collections (`**/*.md` masks). Chunking is content-based,
  not heading-based; messy Markdown is fine.
- Not a replacement for code search — use code search for source trees.

## Common commands

```bash
qmd search "query"             # default BM25
qmd search "query" -c notes    # restrict to a collection
qmd search "query" -n 10       # more results
qmd search "query" --json      # agent-friendly output
qmd search "query" --all --files --min-score 0.3
qmd get "path/to/file.md"      # full document
qmd get "#docid"               # by ID from search results
qmd multi-get "a.md, b.md, #abc123" --json
qmd status                     # index health
qmd update                     # re-index changed files (fast)
qmd embed                      # (re)compute embeddings for semantic search
```

## Keeping the index fresh

`qmd update` is enough for BM25 freshness; run it after bulk edits or
on a schedule (e.g. systemd user timer / cron `0 * * * * qmd update`).

## Models and cache

Local GGUF models auto-download on first embedding run.
Default cache: `~/.cache/qmd/models/` (override with `XDG_CACHE_HOME`).
