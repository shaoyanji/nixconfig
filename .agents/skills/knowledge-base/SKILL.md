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

A **design record** sits beside these: `AGENTS.nix` (`.agents/notes`) and its
lineage. It answers "has this been tried, and what did it come out of?" —
`qmd` cannot, because the record is data, not markdown.

The graph (`.#knowledgeGraph`, below) is a **projection** over 1 + 2, not a fifth
source of truth.

## 2. Query ladder

```bash
# 0. a NOVEL task: has the design record been here already?
task ops:notes:near Q="backups have never been restored"   # ranked + lineage

# 1. structural question about the fleet
nix eval --json .#inventory.hosts.frieren.role | toon -e
nix eval --json .#agentSkills.byTag.nix | toon -e

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
(`mentions` from docs/skills, `tagged` from skills) out of the files themselves.
Mentions are **exact-token** matches, not substrings — `dev` does not match
`devji` — so a count means "this name appears as a word in that file".

**Query it explicitly, don't describe it in English.** The graph has six fixed
traversals — the `jq` analogue of a Cypher `MATCH`. If you know which question
you are asking, call one of these; a classifier in the middle can only get it
wrong (`scripts/task/kg-query.sh` is the single implementation).

| Pattern | Task | Means |
| :--- | :--- | :--- |
| host | `ops:kg:host HOST=frieren` | docs and skills that mention the host |
| skill | `ops:kg:skill SKILL=qmd` | inbound mentions **+** the skill's tags |
| doc | `ops:kg:doc DOC=docs/x.md` | hosts and skills that document names (the reverse direction) |
| tag | `ops:kg:tag TAG=nix` | `(Skill)-[:TAGGED]->(Tag)` |
| comention | `ops:kg:comention HOST=cassini MIN=2` | two hops: hosts sharing documents, ranked |
| stats | `ops:kg:stats` | counts by node type + edge total |

```bash
task ops:kg                                # stats + top out-degree nodes
task ops:kg:comention HOST=poseidon        # the one multi-hop question
task ops:ask Q="what should I read before touching minyx"   # sugar: rules, then bundle
task ops:kg:blast TARGET=<id>              # reverse closure; jq has no one-liner
```

The sidecar, its measured timings and the `--native` parity experiment live in
`AGENTS.md` (*Structural queries are the graph, not grep*); `task ops:kg:speed`
re-measures both paths rather than quoting a ratio that moves with tree state.

Use the six patterns for *"what touches X"*, a question BM25 is bad at. Use `qmd`
for *"where is this explained"*, which a graph is bad at. Before **applying** a
change the same question about paths is `task checks:blast STAGED=1`; `unmapped`
is information, not an error — `modules/` and `flake/` are not graph nodes.

Every pattern takes **`FORMAT=json`** and returns the same envelope:
`{pattern, arg, count, results}` — `results` is a list of ids, except `comention`
(`{id, shared}`) and `stats` (one object of counts).

The exit contract lives in the script: **0** = answer (possibly empty), **1** =
graph unavailable, **2** = no such node, with near-match hints. `go-task` collapses
any failure to **201**, so through `task` read `error:"no_such_node"` +
`suggestions` from the JSON instead of the exit code. An unmentioned node is a
successful empty answer; a typo is never silently one.

```bash
task ops:kg:host HOST=frieren FORMAT=json | jq -r '.results[]'
task ops:kg:host HOST=friere FORMAT=json   # error + suggestions, exit 201
```

### jq cookbook — the questions the six patterns do not cover

Snapshot the graph first; **every count below is live, so re-run rather than
cite**:

```bash
nix eval --json .#knowledgeGraph.graph > /tmp/kg.json
```

**1. What touches X** (inbound mentions — "what should I read before editing
this host"):

```bash
jq -r --arg n host:frieren '.edges[] | select(.to == $n) | .from' /tmp/kg.json | sort -u
```

**2. What one document names** (outbound — the question `ops:kg:doc` also
answers, useful when you have the file open):

```bash
jq -r --arg n doc:docs/task-control-plane.md '.edges[] | select(.from == $n) | .to' /tmp/kg.json | sort -u
```

**3. Orphan documents** — named by nobody, so no query will ever reach them:

```bash
jq -r '[.edges[].from] as $from | .nodes[]
  | select(.type == "doc") | select(.id as $i | $from | index($i) | not) | .id' /tmp/kg.json
```

**4. Skills no document mentions** — the invisible half of the roster:

```bash
jq -r '[.edges[] | select(.to | startswith("skill:")) | .to] as $seen
  | .nodes[] | select(.type == "skill")
  | select(.id as $i | $seen | index($i) | not) | .id' /tmp/kg.json
```

**5. Host blast radius** — how many docs and skills a change to that host's
configuration can invalidate:

```bash
jq -r '. as $g | $g.nodes[] | select(.type == "host") | .id as $h
  | [$h, ([$g.edges[] | select(.to == $h)] | length)] | @tsv' /tmp/kg.json | sort -k2 -nr
```

The `. as $g` binding in 5 is load-bearing: inside `.nodes[]` the current value
is the node, so `.edges` there would be null and every count would print 0 — a
wrong answer that looks like a tidy result.

Read "skills no document mentions" as "no doc names this exactly", not "nobody
uses it". Only the four root living documents and non-recursive `docs/*.md` are
doc nodes (`lib/knowledge-graph.nix`), so a skill listed only in
`.agents/README.md` has no inbound edge, and matching is exact-token, so a note
saying `nix-eval-jobs` does not reach `nix-eval`. For a fleet-visible roster,
`nix eval --json .#agentSkills.byTag` is the source.

`from` is only ever a doc (`doc:<path>`) or a skill (`skill:<name>`); hosts and
tags are only `to` ends, so filtering on `from=="frieren"` matches nothing.

`ops:ask` is deterministic and offline: rules answer the rule-shaped set, and a
question that names a node gets that node's whole context (`route: bundle`). It
is a convenience for a human phrasing a question, not the supported way for an
agent to query a graph it can already name — call the pattern. `ops:bench:kg`
prints the router evidence; no model is on the default path.

Do not run a Neo4j server for a ~10³-node graph on an 11 GiB host that already
swaps. The generated graph plus the Cypher export (`.#knowledgeGraph.cypher`)
is the production path; a `cypher-shell` import against an external instance is
a 30-second operation, not a service.

## 4. Why agent learnings do not reach the vault

The diagnosis is **discoverability and write-path**, not search:

1. **No automatic write path.** Sessions end; nothing summarizes them into the
   vault. `ai-memory` captures pages, but nothing mirrors them to Obsidian.
2. **Two vocabularies.** Repo docs say `HOST=`, `checks:host`; vault notes say
   "frieren rebuild". BM25 over one collection cannot bridge that.
3. **The vault is mounted, not owned.** `/Volumes/data/Obsidian-Git-Sync` is
   NFS; an agent writing there from a host without the mount silently fails or
   writes to a local path.

The proposed fix (note `p2-vault-write-path`): a `vault-sync` timer that exports
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
| A design decision | an `AGENTS.nix` note with `refs`, plus `from` naming what it grew out of (`task ops:notes:near` first) |
| A one-off finding | the commit message / PR; promote only if it changes a rule |
| A procedure | `docs/` or a skill |
| A personal note | the vault |

Never create a new markdown file at the repo root. Roots are for the eight
living documents in `SCHEMA.md`.
