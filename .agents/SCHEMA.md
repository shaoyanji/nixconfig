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
| Generated docs are never committed | `.gitignore` + review — `.#docs` is a store path (`docs/docs-pipeline-audit.md`) |
| Task graph (duplicate keys, dangling refs) | `task checks:tasks` |
| Everything else here | review; `task checks:docs:budget` prints the counts |

---

## 1. One fact, one home

| Fact class | Canonical home | Everyone else links |
| :--- | :--- | :--- |
| Fleet membership, hardware, status | `inventory.toml` (compiled by `lib/inventory.nix`) | `.#inventory`, `.#docs` (`nix build`) |
| Optional profiles / services / knobs | `modules.toml` | `.#docs` → `modules-registry.md` |
| What is executable | `taskfiles/*.yml` | `AGENTS.md`, skills |
| What a host runs | `hosts/<host>/*.nix` | `MANUAL.md` (service map) |
| Why a design exists | `ARCHITECTURE.md` | `EXPERIMENTS.md` evidence links |
| What is still open | `TODO.md` (priority stack) | `ARCHITECTURE.md` exit criteria |
| What happened | `AUDIT.md` (ledger) + `docs/history/` | commit messages |
| How to operate | `MANUAL.md`, `.agents/deploy/` | skills |
| How an agent should route | `AGENTS.md`, `.agents/README.md` | skills |
| What a skill can do | `.agents/skills/<name>/SKILL.md` | `.#agentSkills` index |

**Never** paste a fleet table into a second file. Query `.#inventory` or link to
the generated page. A table that exists twice is a table that disagrees with
itself within a month.

## 2. Document classes and budgets

| Class | Files | Budget | Contains |
| :--- | :--- | ---: | :--- |
| **Manual** | `AGENTS.md`, `MANUAL.md` | 1 200 lines each | routing, invariants, operator procedure |
| **Proposals** | `ARCHITECTURE.md` | 600 lines | P0–P3 proposals, decisions, exit criteria |
| **Studies** | `EXPERIMENTS.md` | 80 lines/entry | mode, evidence, why not prod |
| **Ledger** | `AUDIT.md` | 150 lines | current state + dated entries, newest first |
| **Queue** | `TODO.md` | 150 open items / 300 lines | open items only, priority-ordered |
| **Queue** | `HANDOFF.md` | 150 lines | open items only, priority-ordered |
| **Runbook** | `.agents/deploy/**`, `docs/*.md` | 400 lines | repeatable procedure |
| **Skill** | `.agents/skills/*/SKILL.md` | 400 lines | routing + procedure, not a novel |
| **History** | `docs/history/*.md` | unlimited | superseded narrative, never linked as current |

Over budget is a signal to move detail to `docs/` and leave a pointer — not to
raise the budget. A living document that grows monotonically is not a manual,
it is a diary.

A **queue** is counted twice, because a queue is judged by what is still *open*:
`TODO.md` allows 150 unchecked items (`- [ ]`) **and** 300 lines in total. Checked
items cost against the total and never against the open budget — deleting the
record of finished work to make room is exactly what the split forbids. The gate
(`checks.<system>.docs-budget`) and the human view (`task ops:docs:budget`) print
both numbers.

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

Validate with:

```bash
nix eval .#agentSkills.count                 # 1.2 s, no host eval
nix build .#checks.x86_64-linux.skills-schema -L
```

## 5. Experiment lifecycle

```
idea → EXPERIMENTS.md (study, evidence, exit criteria)
     → ARCHITECTURE.md (proposal, priority, decision)
     → module + host wiring + check
     → EXPERIMENTS.md entry deleted, DELIVERED row in AUDIT.md
```

An experiment that has been "delivered" but is still imported by a host is not
an experiment — it is either prod (document it) or rot (remove it). The
classification banner at the top of `EXPERIMENTS.md` is the rule.

## 6. Anti-pollution checklist (before adding a paragraph)

- Is this fact already in `inventory.toml`, `modules.toml`, or a taskfile?
  Link instead of repeating.
- Is this history? Put it in `docs/history/` and add one ledger line in `AUDIT.md`.
- Is this a proposal? `ARCHITECTURE.md`, with an exit criterion.
- Is this a one-off measurement? Keep it in the PR/commit; only the conclusion
  belongs in the doc.
- Does it name a command that does not exist? Run it before writing it.
- Is it longer than the budget? Move it, don't grow the file.
