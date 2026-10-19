---
name: knowledge-base
description: "Where fleet knowledge lives and which store to query first: compiled Nix truth, prose (qmd), episodic ledger, personal vault, and the graph projection."
version: 0.1.0
author: Shaoyan Ji (shaoyanji)
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [knowledge, memory, qmd, graph, vault, search]
    related_skills: [qmd, ai-memory, master-toon, host-facts, fleet-sentinel]
---

# knowledge-base — find the right store before searching

There is no single knowledge base. There are four, and using the wrong one is
why "I searched and found nothing" keeps happening.

## 1. The four stores

| Store | Contents | Query | Freshness |
| :--- | :--- | :--- | :--- |
| **Compiled truth** | `inventory.toml`, `modules.toml`, `.agents/skills`, flake wiring | `nix eval .#…` (0.1–2 s) | exactly the deployed tree |
| **Prose** | `AGENTS.md`, `MANUAL.md`, `docs/`, runbooks, skills | `qmd search` (BM25, `-c nixconfig`) | as of the last index |
| **Episodic** | sentinel ledger, journald, generations, restic runs | `task ops:ledger`, `journalctl` | live |
| **Personal** | Obsidian vault (`/Volumes/data/Obsidian-Git-Sync`) | `qmd search -c vault`, direct read | as of the last sync |

The graph (`.#knowledgeGraph`, below) is a **projection** over 1 + 2, not a fifth
source of truth.

## 2. Query ladder

```bash
# 1. structural question about the fleet
nix eval --json .#inventory.hosts.frieren.role
nix eval --json .#agentSkills.byTag.nix

# 2. concept/runbook question
qmd search "impermanence disko" -c nixconfig
qmd search "restic drill" -c nixconfig,skills

# 3. what happened / is happening
task ops:health
task ops:ledger | jq -r 'select(.state=="degraded")'
journalctl -u nixos-upgrade -n 40 --no-pager

# 4. what I wrote for myself
qmd search "zettel" -c vault
```

Escalate only when the previous rung answered nothing: vault → wiki (qmd) →
ai-memory (deep, jev-gated). Do not start at an LLM.

## 3. Structural search: the graph, not grep

`.#knowledgeGraph` compiles nodes (hosts, skills, docs, tags) and edges
(`mentions` from docs/skills, `tagged` from skills) out of the files themselves:

```bash
task ops:kg                                    # stats + top-connected nodes
task ops:kg:host HOST=frieren                  # docs and skills that mention it
nix eval --json .#knowledgeGraph.graph --apply 'g: g.edges' \
  | jq -r '.[] | select(.from=="doc:MANUAL.md") | .to'
nix eval --raw .#knowledgeGraph.cypher | head -40   # optional Neo4j import
```

The value is **one hop from a name to its context**: `ops:kg:host HOST=frieren`
lists every doc and skill that names the host, without `grep` and without
reading them. Counts are printed live, never stored. Note that `from` is
only ever a doc (`doc:<path>`) or a skill (`skill:<name>`); hosts and tags are
only `to` ends, so filtering on `from=="frieren"` matches nothing.

Use it to answer *"what touches X"* — a question BM25 is bad at. Use `qmd` for
*"where is this explained"*, which a graph is bad at.

**Neo4j verdict (2026-10-19):** do not run a Neo4j server on frieren. The JVM
heap competes with the NAS's page cache on an 11 GiB host that already swaps,
and the graph is ~10³ nodes — it fits in a JSON file and a `jq` expression.
`hosts/frieren/tools.nix` keeps `neo4j` in the heavy optional set for
experiments; the production path is the generated graph + Cypher export for an
external instance if one ever exists. A `cypher-shell` import is a 30-second
operation against the export, not a service.

## 4. Why agent learnings do not reach the vault

The diagnosis is **discoverability and write-path**, not search:

1. **No automatic write path.** Sessions end; nothing summarizes them into the
   vault. `ai-memory` captures pages, but nothing mirrors them to Obsidian.
2. **Two vocabularies.** Repo docs say `HOST=`, `checks:host`; vault notes say
   "frieren rebuild". BM25 over one collection cannot bridge that.
3. **The vault is mounted, not owned.** `/Volumes/data/Obsidian-Git-Sync` is
   NFS; an agent writing there from a host without the mount silently fails or
   writes to a local path.

The proposed fix (ARCHITECTURE.md P2): a `vault-sync` timer that exports
`ai-memory` pages + `docs/history/` into `Obsidian-Git-Sync/inbox/` with a
stable frontmatter block (`source`, `host`, `date`, `status`), then Git commits.
The rule: **agents write to one inbox, a timer curates; nobody hand-maintains a
second vault.**

## 5. Where to record something

| It is… | Write it to |
| :--- | :--- |
| A durable rule | `.agents/SCHEMA.md` or the owning manual |
| A host fact | `inventory.toml` (`notes`) via `task dev:inventory:menu` |
| An operational event | the sentinel ledger (automatic) + `AUDIT.md` line |
| A design decision | `ARCHITECTURE.md` |
| A one-off finding | the commit message / PR; promote only if it changes a rule |
| A procedure | `docs/` or a skill |
| A personal note | the vault |

Never create a new markdown file at the repo root. Roots are for the eight
living documents in `SCHEMA.md`.
