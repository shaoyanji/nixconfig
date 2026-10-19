# ARCHITECTURE — mk2

> **This file is the proposal layer.** `EXPERIMENTS.md` is the archive of design
> studies; `AUDIT.md` is the ledger of what changed; `TODO.md` is the priority
> stack. A proposal moves here when it has a decision to make, and it leaves
> here when it is `DELIVERED` (one ledger line in `AUDIT.md` remains).
>
> Status vocabulary and budgets: `.agents/SCHEMA.md`.

## 0. The shape in one page

```
                      ┌─────────────────────────────────────────────┐
 INVENTORY (truth)    │ inventory.toml ─► lib/inventory.nix ─┐      │
                      │ modules.toml   ─► modules registry     │      │
                      └───────────────────────────────────────┼──────┘
                                                              ▼
 FLAKE (assembly)     flake/outputs.nix ─► host configs, checks, docs,
                                          agentSkills, knowledgeGraph
                                                              │
 CONTROL PLANE        taskfiles/*.yml ─────────────────────────┤
                      scripts/task/* (bodies only)             │
                                                              ▼
 DEPLOYMENT           hosts/*.nix + modules/*.nix ─► system closure
                                                              │
 OBSERVATION          fleet-sentinel (15 min) ─► ledger.jsonl ─┤
                      gatus ─► SimpleX bridge                  │
                      qmd (prose) · knowledgeGraph (structure) ◄┘
```

The rule that keeps this from rotting: **each layer only consumes the layer
above it.** A host does not parse TOML; a skill does not re-derive fleet facts;
a monitor does not read the Nix store. Everything else is a duplicate source of
truth waiting to disagree.

## 1. Decisions (ADRs)

| ID | Decision | Status | Consequence |
| :--- | :--- | :--- | :--- |
| D1 | Context is **compiled**, not hand-maintained (`lib/inventory.nix`, `lib/skills.nix`, `lib/knowledge-graph.nix`) | DELIVERED 2026-10-19 | Adding a skill/host is a file, not a table edit; every consumer agrees |
| D2 | **Eval-first**: a question is a `nix eval` before it is a script | DELIVERED (measured, §6) | 1–2 s answers; no new Python glue |
| D3 | Observation is an **append-only ledger**, not a dashboard-first metric store | DELIVERED 2026-10-19 | `fleet-sentinel`; `jq`/TOON queryable; gatus only pages |
| D4 | **No Neo4j server on frieren**; graph is a projection + Cypher export | REJECTED (server) / DELIVERED (projection) | no JVM heap on an 11 GiB NAS; `.#knowledgeGraph` is the query path |
| D5 | **One** fleet-wide skill tree, materialized by Home Manager | DELIVERED 2026-10-19 | `modules/user/ai/skills/default.nix`; `force` replaces stale copies |
| D6 | Living documents have **budgets**, history moves to `docs/history/` | DELIVERED 2026-10-19 | `task ops:docs:budget`; bounded context |

## 2. P0 — Context plane (DELIVERED 2026-10-19)

**Problem.** 40+ skills, 4 manuals, and 3,800 lines of experiments were indexed
by hand. `AGENTS.md` and `.agents/README.md` each carried a table that could
disagree with the tree; nothing rejected a skill with no description. Agent
context was growing while its signal density fell.

**Delivered.**

- `lib/skills.nix` parses frontmatter, normalises optional fields, and emits
  `.#agentSkills` (index + tags) and `.#agentSkillsBundle`. Hard gate:
  `checks.<system>.skills-schema`.
- `lib/knowledge-graph.nix` emits `.#knowledgeGraph` (34 hosts, 43 skills,
  21 docs, 416 mention edges) and a Cypher export. It is a projection; it
  derives from the same files the fleet deploys.
- `.agents/SCHEMA.md` — one fact one home, document budgets, status vocabulary,
  skill contract, experiment lifecycle.
- `.agents/README.md` — a router to the compiled index, not a second table.
- Living docs rebuilt around the schema: this file (proposals), slim
  `AUDIT.md`/`TODO.md`/`HANDOFF.md`, indexed `EXPERIMENTS.md`.

**Exit criterion (met).** `nix eval .#agentSkills.count` answers in ~1.2 s;
`task ops:skills:check` fails on a malformed skill; no hand-maintained skill
table remains in the repo.

**Home card (delivered 2026-10-19).** `lib/home-agents.nix` renders
`.#homeAgents.<host>` from the compiled inventory + `docs/agent-context/HOME-PREAMBLE.md`
+ persona; activation links the store path. The Python `--home-agents` path was
deleted. `compile-llm-specs.py` survives only for the fleet-matrix table (P4).

## 3. P1 — Close the loop fleet-wide (`IN FLIGHT`)

**Problem.** `fleet-sentinel` observes **frieren only**. When fern's `nix-gc`
dies on an unreachable NAS, or eisen's generation is three weeks old, nothing
records it: the host is simply absent from every dashboard. "The plumber" only
sees a socket, not a job.

**Decision.** Do **not** add an agent/daemon per host. The observation unit is
the same `fleet-sentinel` module, and it gains one optional egress:
`services.fleetSentinel.pushUrl`. The collector already produces one small JSON
object per run (`~400 B`); a host with the option enabled POSTs it to frieren
behind the existing nginx vhost (`/sentinel/ingest`), which appends to
`/var/lib/fleet-sentinel/hosts/<host>.jsonl`.

Transport and auth, in order of preference:

1. **HTTPS + a sops-shared bearer token** through the existing `sentinel` vhost
   (one new location, no new port).
2. If the LAN is unreachable: the tailnet address, same token.
3. Never SSH in an unattended path (EXP-113: Tailscale's browser check hung a
   run for five minutes).

**Why not MQTT yet.** The broker has no publisher/subscriber (HC-5), and adding
one to route six small JSON objects per hour is more moving parts than an HTTP
POST. Revisit when EXP-007's bus exists.

**Deliverable.**

- `pushUrl`/`pushTokenFile` options; `curl --max-time 5` with a non-fatal
  failure (an offline laptop must not fail its own collector).
- An ingest location that appends `hosts/<host>.jsonl` under a `client_body`
  limit of 8 KiB and a systemd tmpfiles dir.
- `task ops:fleet` merges the host files into one table (last event per host).
- A gatus endpoint per *critical* host is deliberately **not** added: the
  missing-host case is the signal, and a per-host endpoint list would be another
  hand-maintained table.

**Exit criteria.**

1. Three hosts push for a week; `ops:fleet` shows every host's last event.
2. One host powered off shows `stale:>2h`, not a missing row.
3. No new fingerprintable port; ingest is behind the existing vhost.
4. `checks:ports` stays clean.

## 4. P2 — A real write path to the vault (`PROPOSED`)

**Problem.** Agent learnings do not reach the Obsidian vault, and the cause is
**not search**: there is no automatic write path. `ai-memory` captures pages,
nothing mirrors them to `/Volumes/data/Obsidian-Git-Sync`, and an agent on a host
without the NFS mount writes to a local folder that never syncs. Two vocabularies
(`HOST=`, `checks:host` vs "frieren rebuild") make cross-collection BM25 weak.

**Decision.** One inbox, one curator, no second vault:

```
ai-memory pages ─┐
docs/history/*  ─┼─► vault-sync.timer (frieren, 30 min)
sentinel event  ─┘        │
                          ├─► /Volumes/data/Obsidian-Git-Sync/inbox/<date>-<host>.md
                          └─► git commit (vault repo)
```

- Frontmatter contract: `source`, `host`, `date`, `status`, `tags`.
- **One file per day per host**, append-only; the human curates from the inbox
  into zettels. The timer never overwrites a curated file.
- Generated tables go to `inbox/tables/` as a link to `.#knowledgeGraph`, never
  as hand-maintained markdown.
- The sync is a oneshot with `Nice=10`, `IOSchedulingClass=idle`, and **no
  delete**: a vault that disappears (NFS down) must fail the unit, not the
  source data.

**Exit criteria.** A week of sessions produces exactly one inbox file per active
host per day; `qmd search -c vault` returns an inbox hit; removing the NAS mount
makes the unit fail loudly and lose nothing.

**Rejected.** Writing directly into dated zettels (pollutes the human graph),
and a second agent-owned vault (two sources of truth).

## 5. P3 — Query model: graph vs prose vs `qmd` (`DELIVERED`, Neo4j `REJECTED`)

**Problem.** "Which skills mention frieren?" and "what touches the restic
drill?" are graph questions; `qmd` (BM25) answers "where is this explained".
The repo had no structural query path, so every such question became `grep`
plus a guess.

**Delivered.** `.#knowledgeGraph` compiles hosts, skills, docs and mention edges
from the files themselves (~10 s cold because it reads every living doc). It
ships as JSON and Cypher; `task ops:kg` / `ops:kg:host HOST=` query it with `jq`.

**Neo4j verdict: rejected as a service.** The graph is ~10³ nodes and ~10²
edges. A Neo4j JVM (default heap 512 MiB–1 GiB, plus page cache) competes
directly with the NAS page cache on this 11 GiB host, which already swaps. The
Cypher export exists so an *external* instance can be fed in one command; it
does not justify a local daemon. If the graph ever needs multi-hop queries that
`jq` cannot express, the next candidate is an embedded engine (SQLite recursive
CTEs or Kuzu), not a server.

**Boundary.** The graph is a projection: if it disagrees with `inventory.toml`
or a skill file, the source wins and the projection is stale. Regenerate; never
edit it.

## 6. P4 — Taskfiles → evals, and the last Python (`IN FLIGHT`)

**Problem.** The control plane is ~380 tasks and ~30 shell helpers. Some are
indispensable operator workflows; others are glue that re-implements what Nix
already knows (`compile-llm-specs.py` re-parses `inventory.toml`;
`inventory-menu.sh` shells out to `yq` for data the flake has compiled). Python
survives in `compile-llm-specs.py` and a few prototypes.

**Decision — the migration ladder** (full table in the `task-plane` skill):

1. `nix eval` for a question about compiled data.
2. `jq`/`yq` on a compiled artifact.
3. A `lib/*.nix` function when the rule is fleet-wide.
4. A `checks:*` gate when it must fail a build.
5. A task only for a repeatable operator workflow.
6. A script only as the body of (5).
7. A **Go** binary when it ships to hosts or needs real parsing/concurrency.

**Measured** (`task ops:bench:evals`, frieren, warm):

| Route | Wall (warm) | Validates? |
| :--- | ---: | :--- |
| `nix eval --raw .#inventory.hosts.frieren.role` | 151 ms ± 13 | yes (schema + normalisation) |
| `yq -r '.hosts.frieren.role' inventory.toml` | 42 ms ± 6 | no |
| `python3 -c 'tomllib…'` | 44 ms ± 3 | no |
| `nix eval --json .#agentSkills.count` | 120 ms ± 14 (1.2 s cold) | yes (43 skills parsed + validated) |

The eval is ~3.5× `yq` and worth it whenever the answer must match what
deploys. `yq` wins for a single raw field in a human's shell. The cold-vs-warm
gap is mostly flake evaluation, not the skill parse.

**Rebuild discipline (2026-10-19).** Local `infra:switch:*` / `infra:rebuild:*`
no longer run a pre-flight check. `warm-host.sh --check` was removed from the
switch path because it forces the whole host toplevel (`drvPath`, `outPath`, and
a `nix build --dry-run`) — a second full evaluation immediately before the
rebuild performs the same one. `NOM=1` is opt-in and set only by the human TUI;
agent runs get plain output and the real exit status. `checks:build:route`
remains available as an explicit CI/operator gate.

**Deliverables.**

1. **Delivered 2026-10-19.** `lib/home-agents.nix` → `.#homeAgents.<host>`;
   activation links the store path; the Python `--home-agents`/`--sync-home`
   paths and the `generate_home_agents` renderer were deleted.
2. Delete `--sync-docs`/`--compile-fleet` paths once `lib/docs.nix` covers the
   remaining tables (it already owns the fleet inventory and modules registry).
3. Port the two shell helpers that are actually algorithms (closure budget
   adopt, port audit) to a single Go `nixctl` **only if** they grow past ~150
   lines; otherwise leave them as task bodies.
4. Hooks: formatting/lint stay in pre-commit; everything that *proves* something
   becomes a flake check (`checks.<system>.*`) so CI and humans run the same
   code. No new `scripts/` entrypoint.

**Exit criteria.** No Python in the activation path (met: the only remaining
Python is the offline fleet-matrix generator); `task checks:quick` and CI run
the same Nix checks; `task-plane`'s rung table has no exceptions left.

## 7. P5 — Aesthetics & DankMaterialShell integration (`PROPOSED`)

**Problem.** The sentinel is truthful but not *present*: it lives at a URL and a
CLI. The operator already has a DMS/Niri desktop (frieren, eisen, stark,
deckstation), and a degraded NAS should be visible there without opening a
browser.

**Decision.** Integrate at the **shell** layer, not by forking DMS:

1. **One widget, one file.** A DMS custom module reads
   `http://127.0.0.1:80/sentinel/status.json` (loopback; already served) and
   renders `state`, `generation_age_h`, and the first two reasons. No token
   plumbing, no daemon.
2. **Palette from the status, not a new theme.** `ok` → `#a6e3a1`, `degraded` →
   `#f38ba8`, accent `#89b4fa` (the dashboard already uses these). DMS wallpapers
   and the sentinel share the same Catppuccin Mocha tokens; the alert does not
   invent a second palette.
3. **Notifications at the transition, not every poll.** Gatus already has a
   3-failure threshold and the SimpleX bridge; DMS should surface the *same*
   transition via `notify-send` on hosts with a session. The ledger stays the
   record.
4. **Kando/menu entry**: `fleet status` → opens `sentinel.frieren.lan`; this is
   a config entry, not a new app.

**Exit criteria.** On a degraded sentinel, a DMS login shows a red card within
one poll and one notification; on recovery, one resolved notification. No new
service, no new port, no second source of truth.

**Alternative considered.** Quickshell or a Waybar module instead of DMS — both
work, but the fleet standard is DMS and maintaining two widgets is the failure
mode this repo keeps repeating.

## 8. P6 — Canary as the promotion gate (`PROPOSED`)

**Problem.** EXP-102 delivered a MicroVM canary, but promotion of a risky module
is still "it evaluated on frieren". The eval-vs-build distinction is understood
(EXP-114), yet there is no cheap runtime proof between them.

**Decision.** A one-shot promotion gate for changes that add a *unit*:

```bash
task vm:canary:build && task vm:canary:test   # boot → ssh → proxy → stop
```

Wire it as an optional CI job for PRs touching `modules/services/**` (runner
with KVM); never as a default local gate. Exit criteria: a deliberately broken
unit fails the canary; a good one passes in under 3 minutes.

## 9. Sequencing

| Order | Item | Depends on | Effort |
| ---: | :--- | :--- | :--- |
| 1 | P0 (done) | — | — |
| 2 | P1 sentinel push | P0 ledger | 1 module + 1 nginx location |
| 3 | P4 home-card in Nix | — | 1 lib + activation swap |
| 4 | P2 vault inbox | P1 (events) | 1 timer + 1 script → Go later |
| 5 | P5 DMS widget | P1 health endpoint | 1 config file |
| 6 | P6 canary gate | CI KVM | workflow change |
| — | P3 server (rejected) | — | — |

## 10. Non-goals

- A second fleet table anywhere (including this file).
- A monitoring database on frieren. The ledger is bounded; export if needed.
- A per-host agent daemon for observation.
- Neo4j as a local service.
- Rewriting `taskfiles/*` wholesale. Migrate by *deleting* a task when its eval
  replaces it, not by moving 380 tasks in one commit.

## 11. Measurements appendix

Recorded on frieren, 2026-10-19, warm store, host otherwise loaded:

| Operation | Wall | Notes |
| :--- | ---: | :--- |
| `nix eval .#agentSkills.count` | 0.12 s warm / 1.2 s cold | 43 skills, parses every frontmatter |
| `nix eval .#knowledgeGraph.graph.stats` | 9.7 s cold | reads 21 docs, 34 hosts, 43 skills |
| `nix eval .#inventory.hosts.frieren.role` | 0.15 s warm | compiled registry, no host eval |
| `nix eval .#nixosConfigurations.frieren.config.systemd.services.fleet-sentinel.serviceConfig.ExecStart` | 7.9 s | one host module system |
| `nix build .#checks.x86_64-linux."skills-schema"` | <1 s after eval | gate derivation |

Never run `nix flake check` here (339.78 s / 6 GiB / SIGKILL 137 — AGENTS.md).
