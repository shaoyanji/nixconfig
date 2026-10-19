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
task ops:kg                                    # stats + top out-degree nodes
task ops:kg:comention HOST=poseidon            # the one multi-hop question
task ops:ask Q="what should I read before touching minyx"   # sugar: rules, then bundle
task ops:ask:jev Q="…"                         # same, with a Jev check recorded
task ops:bench:kg                              # re-run the router evidence
task ops:context                               # monitor state + host context
nix eval --raw .#knowledgeGraph.cypher | head -40   # optional Neo4j import
```

**The sidecar** (`task ops:kg:sidecar`, engine in `tools/kg-engine/`) serves the
same graph from memory over `unix:$XDG_RUNTIME_DIR/kg.sock`: 58 µs server-side,
36–50 ms per query through the script, 114–125 ms through `task` (measured
2026-10-19) — against ~113 ms for the jq surface on a clean tree and ~530 ms on
a dirty one, so it pays off for repeated queries, not a single lookup.
It loads the COMPILED projection by default (`--native` selects the engine's own
builder, which is what `checks:kg:native` measures for parity), so the socket and
the jq surface read one graph — and `checks:kg:native` runs inside
`checks:quick`, because a second builder that silently trails the projection is
worse than no daemon at all. `elixir` comes from PATH in the repo's devshell
(`.envrc`), the store otherwise, so a warm machine never calls nix to start it.
Use it for many questions in a row, or for `ops:kg:blast TARGET=<id>` —
transitive dependents, the one traversal the jq patterns do not do.

Before **applying** a change, ask the same question about paths rather than ids:
`task checks:blast STAGED=1` (or `FILES="hosts/frieren/reverse-proxy.nix"`) maps
each path to its anchor and prints what it reaches. `unmapped` is information,
not an error: `modules/` and `flake/` are not graph nodes, and closures are the
tool for those. `checks:kg:sidecar` is the parity gate — it fails if the engine's
graph, answers or error codes disagree with the compiled projection.

**Read the note, don't leave the site.** `http://fleet.frieren.lan` → *Notes*
lists every doc and skill by how often the graph cites it; clicking one opens its
slice, which contains **that note's own markdown rendered at build time** (the
file is read during evaluation, so there is no forge URL to rot). The
*Knowledge Graph* opens the same slice from a node, and its host slices link to
the inventory page.

**See the graph.** *Knowledge Graph* renders the
projection as a force-directed canvas: pan, wheel zoom, hover to inspect, click
any node to open its static slice (note text where there is one, neighbours, and
the inventory page for a host). Type in the search box to narrow by label or id, and
toggle the per-type chips (host/skill/doc/tag) to filter — the counter follows
the set the renderer uses. Hovering a node, or searching, lights it and its
neighbours while dimming the rest. The filter lives in the URL
(`#kg?q=frieren&types=host,doc`), so a filtered view is a link you can send;
opening one lands directly on the graph. Every click is a fetched JSON slice —
no daemon. The
definition lives in `lib/aki-site.nix`, and the canvas itself is
`lib/site/kg.js` (plain JS, parsed by `checks.<system>.site-assets`);
`task checks:kg:canvas` proves it by
driving headless Chrome through the click, and `task checks:kg:native` holds the
cold bootstrap to **median < 20 ms** with no `nix` subprocess.

**Nothing on the site is typed.** Overview counts, inventory rows, notes and the
closure budgets page are all `${...}` over evaluated data (`inventory.toml` via
`lib/inventory.nix`, `closure-budgets.toml`, the compiled graph) — a figure with
no source of truth is not rendered at all. That is why the site has no "closure
attribution" or "debloat playbook" page any more: both were prose about one
generation. `task checks:kg:canvas` recomputes every budget figure from the file
and refuses a slice whose note does not match its source.

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

The pattern tasks answer the six questions the graph exists for. These five
answer the ones it can still answer in one expression. Snapshot the graph first;
**every count below is live, so re-run rather than cite**:

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

**3. Orphan documents** — named by nobody, naming nothing, so no query will ever
reach them:

```bash
jq -r '[.edges[].from] as $from | .nodes[]
  | select(.type == "doc") | select(.id as $i | $from | index($i) | not) | .id' /tmp/kg.json
```

**4. Skills no document mentions** — the invisible half of the roster. A skill
here still loads when named, but nothing in the docs points at it:

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

Run 2026-10-19 (21 doc nodes, 43 skills, 387 edges): orphan documents were zero
(all eight living docs name something), and **15 of 43 skills had no inbound
mention** — `master-toon`, `nix-eval`, `host-facts`, `decision-picker` among
them. Two causes, both worth
knowing before you read that list as rot:

- **Only two doc sources exist**: the eight living documents at the repo root and
  non-recursive `docs/*.md` (`lib/knowledge-graph.nix`). `.agents/README.md`
  lists skills and is *not* a doc node, so a skill documented only there has no
  inbound edge.
- **Matching is exact-token**: `EXPERIMENTS.md` says `nix-eval-jobs`, which is a
  different token from `nix-eval` — the substring is there, the edge is not.

So the honest reading is "no doc names this exactly", not "nobody uses it". For
a fleet-visible roster, `nix eval --json .#agentSkills.byTag` is the source.

`ops:ask` remains sugar over these: deterministic keywords, a model only when no
rule matched. It is a convenience for a human phrasing a question, not the
supported way for an agent to query a graph it can already name.

Routing (`ops:ask`) is deterministic and offline. Rules answer 14/14 of the
rule-shaped set (labels written from the six intents — that number is
independent). When no rule matches but the question **names a node**, the node's
whole context is returned (`route: bundle`), which takes the paraphrase set from
6/10 to 10/10 at 0 ms — but **4 of those 10 are bundle answers whose gold label
encodes the same policy**, so read them as coverage, not comprehension;
`ops:bench:kg` prints that count next to the score. Hosted Jev is 13/14 and 9/10
at ~330 ms, the in-repo hash engine 5/14 and 1/10. No model is called on the
default path; `KG_DECIDE_ALWAYS=1` opts into Jev as an agreement check only.

The bundle's limits are measured too, not assumed: `--set unnamed` (questions
that name **no** node) is rules 4/9 vs Jev 7/9. Nothing there can trigger the
bundle, because there is no name to resolve — so above 4/9 the rules are only
keywords. Prefer this set's shape: the rules' misses are `UNKNOWN` (visible
declines), Jev's are confident wrong intents. If your question names nothing,
name the thing instead — that is a one-word change that puts the bundle to work.

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
