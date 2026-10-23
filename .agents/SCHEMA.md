# Documentation & Skill Schema

The repo's context was accumulating four failure modes at once: the same fact in
three files, history mixed into living docs, no budget on agent-facing prose, and
skills that were "whatever the last session wrote". This file is the contract that
replaces taste with rules.

Machine-enforced where possible:

| Contract | Enforced by |
| :--- | :--- |
| Skill frontmatter, description length, body budget | `lib/skills.nix` → `checks.<system>.skills-schema` |
| Every tracked `.toml` parses | `task checks:toml:lint` |
| Generated docs are never committed | `.gitignore` + review — `.#artifacts.docs` is a store path (`docs/docs-pipeline-audit.md`) |
| Task graph (duplicate keys, dangling refs, include cycles, name parity) | `task checks:tasks` |
| AGENTS.nix notes: status vocabulary, resolvable refs, leaf intent | `lib/agents-notes.nix` → `checks.<system>.agents-notes-schema` |
| Everything else here | review; `task ops:docs:budget` prints the counts |

---

## 1. One fact, one home

| Fact class | Canonical home | Everyone else links |
| :--- | :--- | :--- |
| Fleet membership, hardware, status | `inventory.toml` (compiled by `lib/inventory.nix`) | `.#inventory`, `.#artifacts.docs` (`nix build`) |
| Optional profiles / services / knobs | `modules.toml` | `.#artifacts.docs` → `modules-registry.md` |
| What is executable | `taskfiles/*.yml` | `AGENTS.md`, skills |
| What a host runs | `hosts/<host>/*.nix` | `MANUAL.md` (service map) |
| Why a design exists, and what is still open | `AGENTS.nix` notes (`task ops:notes`) | `.#agentsNotes`, `.#artifacts.docs` |
| What happened | `AUDIT.md` (ledger) + `docs/history/` | commit messages |
| How to operate | `MANUAL.md`, `.agents/deploy/` | skills |
| How an agent should route | `AGENTS.md`, `.agents/README.md` | skills |
| What a skill can do | `.agents/skills/<name>/SKILL.md` | `.#agentSkills` index |
| What is forbidden, and the proof | `flake/policies.nix` | cite `[[flake/policies.nix#<policy-id>]]`; never restate |

**Never** paste a fleet table into a second file. Query `.#inventory` or link to
the generated page. A table that exists twice is a table that disagrees with
itself within a month.

### Formats, and the tool that owns each

A format is chosen by what reads it, and edited only by a tool that understands
it. This table is the place to look before touching data in place.

| Format | Lives in | Edit with | Guard |
| :--- | :--- | :--- | :--- |
| TOML | `inventory.toml`, `modules.toml` | `yq -p toml -o toml -i`; keep the `.toml` extension, or pass `-p`/`-o` explicitly. `tomlkit` when comments must survive | `task checks:toml:lint` |
| YAML | `taskfiles/*.yml`, `.github/workflows/*.yml` | `yq -p yaml -o yaml -i`; a task graph edit is verified by running it | `task checks:yaml:lint`, `checks:tasks` |
| Nix | `*.nix`, `flake.nix` | editor plus `alejandra`; read a value with `nix eval` instead of re-parsing it | `task checks:nix:format`, `checks:nix:lint` |
| JSON | flake outputs, API bodies, anything feeding `jq` | `jq` | none: a program consumes it |
| JSONL | `/var/lib/fleet-sentinel/ledger.jsonl` | append-only; filter with `jq` | `fleet-sentinel` |
| TOON | nowhere on disk. It is the agent's projection of JSON | `toon -e` / `toon -d`; recount `[n]` with `task dev:toon:fix` | `task checks:toon`, `checks:toon:surfaces` |

TOON never becomes a source of truth. An agent consumes and emits TOON; the
converter crosses to the format that owns the data (`master-toon` skill).

### Rules are predicates, not prose

A prohibition in a document is either **enforced** or it is decoration. The split:

| Kind | Home | Shape |
| :--- | :--- | :--- |
| **Policy** — a rule a machine can check ("no task defaults to the fleet", "TOML through a tool") | `flake/policies.nix` | `{ rule, proof, holds, detail }`; `checks.policies` asserts `holds` for every id. `AGENTS.md` and the skills are shrink-only line budgets — they are read into context every turn: [[flake/policies.nix#agent-prose-budget]] |
| **Procedure** — an action an agent takes ("read the queue before proposing", "ask before deploying") | a skill or a task's `summary` | imperative steps, no rule language |

A document states a policy in one line and cites it: `Never run … [[flake/policies.nix#<policy-id>]]`.
The gate is bidirectional — a citation to an unknown id fails, an id nobody cites
fails (an invisible gate rots), and any line tagged as a hard rule without a
citation fails.
If a sentence cannot be written as a predicate, it is procedure, and it belongs in
a skill instead of the manual.

## 2. Document classes and budgets

| Class | Files | Budget | Contains |
| :--- | :--- | ---: | :--- |
| **Manual** | `AGENTS.md`, `MANUAL.md` | 1 200 lines each | routing, invariants, operator procedure |
| **Notes** | `AGENTS.nix` | data file | decisions, proposals, open work, design studies: status + refs + a distilled body (≤30 lines), or a leaf with verbose intent |
| **Stubs** | `ARCHITECTURE.md`, `TODO.md`, `HANDOFF.md`, `EXPERIMENTS.md` | 10 lines | a pointer to `AGENTS.nix`; content creeping back fails `docs-budget` |
| **Ledger** | `AUDIT.md` | 150 lines | current state + dated entries, newest first |
| **Runbook** | `.agents/deploy/**`, `docs/*.md` | 400 lines | repeatable procedure |
| **Skill** | `.agents/skills/*/SKILL.md` | 400 lines | routing + procedure, not a novel |
| **History** | `docs/history/*.md` | unlimited | superseded narrative, never linked as current |

Over budget is a signal to move detail to `docs/` and leave a pointer — not to
raise the budget. A living document that grows monotonically is not a manual,
it is a diary.

A **note** is judged by whether it can be acted on: a note with refs is distilled
(the code is the detail) and a note without refs is a **leaf** that must carry
the original intent in prose. `AGENTS.nix` has no prose budget because the
schema, not a line count, is what keeps it honest; the four root stubs are
bounded at 10 lines each by `checks.<system>.docs-budget` and
`task ops:docs:budget`.

## 3. Status vocabulary (use these exact words)

| Status | Meaning |
| :--- | :--- |
| `PROPOSED` | written down, not agreed, nothing deployed |
| `ACCEPTED` | agreed; work not started |
| `IN FLIGHT` | partially delivered; say exactly what is missing |
| `DELIVERED` | landed in the tree; link the commit or path |
| `SUPERSEDED` | replaced; link the replacement, do not delete the record |
| `REJECTED` | considered and declined; keep the reason |
| `BLOCKED` | waiting on hardware / another item; name the blocker |
| `OPEN` | queue item, actionable now |

A completed item is not "done" — it is `DELIVERED` with a path. A deleted item
with no record is indistinguishable from an oversight.

## 4. Skill contract

```yaml
---
name: matcher-of-directory      # required; must equal the directory name
description: ≤240 chars, a routing hint: what it does + when to pick it
version: 0.1.0                  # optional (default 0.0.0 → warning)
platforms: [linux]              # optional (default [linux] → warning)
metadata:
  hermes:
    tags: [nix, eval]           # optional; drives `.#agentSkills.byTag`
    related_skills: [task-plane]
---
```

Rules:

1. **The description sells the route, not the topic.** "Pick me when…", not
   "This document describes…". It is the only text an agent sees before loading.
2. **The body is a router plus procedure.** If it exceeds 400 lines, the detail
   belongs in `docs/` and the skill keeps a pointer.
3. **Every command must be executable as written** — no `<placeholder>` that no
   task accepts; use the documented variables (`HOST=`, `MODE=`, `STRICT=`).
4. **State the cost and the proof.** A skill that says "run this eval" must say
   what it proves and what it does not.
5. **No secrets, no live tokens, no personal data.** Reference
   `task infra:sops:get:*` instead.
6. **Prose cites truth, it never becomes it.** Every `SKILL.md` carries a
   `Truth:` line naming a resolvable repo path (`modules/`, `hosts/`, `flake/`,
   `lib/`, `taskfiles/`, `scripts/`) or a policy citation —
   [[flake/policies.nix#skills-cite-truth]] and every channel keeps a route
   [[flake/policies.nix#channels-have-a-task]] and the engine that answers
   [[flake/policies.nix#decision-engine-routing]], and it sends features, not
   contents [[flake/policies.nix#categorize-sends-features-only]]; automation
   itself is earned [[flake/policies.nix#automation-is-earned]]. It names a
   service option,
   never defines one [[flake/policies.nix#services-live-in-modules]]: the skill
   is the procedure, the file is the mechanism.

Validate with:

```bash
nix eval .#agentSkills.count                 # 1.2 s, no host eval
nix build .#checks.x86_64-linux.skills-schema -L
```

## 5. Experiment lifecycle, and its lineage

```
idea → AGENTS.nix note (kind = experiment, status = PROPOSED; leaf → verbose intent)
     → kind = proposal + priority (status ACCEPTED)
     → module + host wiring + check (status IN FLIGHT → DELIVERED, refs.modules)
     → the note stays as the design record; a DELIVERED row in AUDIT.md
```

**Promotion is an edit to the note, never a new markdown file.** Moving up a
rung means adding the artifact that embodies the trying (`refs.modules`), the
gate that proves it (`refs.tasks`), and the new `status` — that is what keeps an
idea from becoming recycled prose. A note whose exit criterion cannot be
executed is not ready to be promoted; creating that `checks:*` task is part of
the work.

An experiment that has been "delivered" but is still imported by a host is not
an experiment — it is either prod (point the note's refs at the module) or rot
(mark it `SUPERSEDED`, or `REJECTED` with the reason; never delete the record).
`task ops:notes KIND=experiment` is the current set.

### Edges: how a new idea reaches an old one

Refs point at code. Edges point at thinking, and a note with neither is a file
nobody finds twice. Three fields; only two of them are directed:

| Field | Claim | Gate (`agents-notes-schema`) |
| :--- | :--- | :--- |
| `links` | same thread, no order claimed | target is a real note |
| `from` (new → old) | this note exists because of that one: grew out of it, closes it, was inspired by it | target is real, no self-edge, no cycle |
| `supersedes` (new → old) | this note replaces that one | target is real **and marked `SUPERSEDED`** |

`ancestors`, `descendants` and `replacedBy` are **derived, never stored** — one
edge, one home. A `SUPERSEDED` note that nothing claims fails the gate, because
SCHEMA §3 says retirement links the replacement and a dead end is not a record.

**Before writing anything, ask the record.** This is the novel-task entry, and
it costs about a second:

```bash
task ops:notes:near Q="backups have never been restored"   # ranked, with lineage + refs
task ops:notes:lineage ID=<note>                           # where it came from, what it led to
```

Read the answer by status, not by relevance alone:

- `DELIVERED` **with** descendants — solved area; read the descendant, do not
  repeat the work. This is what the finished note is *for*.
- `PROPOSED`/`OPEN` **with no descendants** — a frontier: the live end of a line,
  and where a new note attaches with `from`.
- `PROPOSED` **leaf** — an idea that owes a commit; promote or reject it rather
  than adding a second leaf beside it.

Authoring contract, field rules, templates and the verification commands:
`.agents/skills/agents-notes/SKILL.md`.

## 6. Anti-pollution checklist (before adding a paragraph)

- Is this fact already in `inventory.toml`, `modules.toml`, or a taskfile?
  Link instead of repeating.
- Is this history? Put it in `docs/history/` and add one ledger line in `AUDIT.md`.
- Is this a proposal or open work? An `AGENTS.nix` note with an exit criterion
  and refs to the nodes it affects (or a verbose leaf if none exist yet).
- Does it grow out of something that already exists? Add `from`. An idea with no
  ancestry is indistinguishable from one nobody checked, and gets re-litigated.
- Is this a one-off measurement? Keep it in the PR/commit; only the conclusion
  belongs in a note.
- Does it name a command that does not exist? Run it before writing it.
- Is it longer than the budget? Move it, don't grow the file — and a root
  narrative file is now a 10-line pointer, not a home.
