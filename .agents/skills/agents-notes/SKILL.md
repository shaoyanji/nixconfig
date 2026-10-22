---
name: agents-notes
description: "Pick me when writing or promoting an AGENTS.nix note (experiment, proposal, open todo, handoff): kind and status choice, refs that must resolve, exit criteria, and promotion that lands code instead of prose."
version: 0.1.0
platforms: [linux]
metadata:
  hermes:
    tags: ['notes', 'agents', 'experiments', 'handoff', 'todo', 'promotion']
    related_skills: ['knowledge-base', 'task-plane', 'checks']
---

# agents-notes — author the trying, then promote the code

`AGENTS.nix` is where a design idea lives **before and after** the code exists.
The failure this skill prevents is the expensive one: an idea is written as
prose, "graduates" by being copied into a second markdown file, and the code
that was supposed to embody it never lands. A note is not a diary entry — it is
a claim with a pointer and an exit.

## The contract

Every note is exactly three things:

1. **A claim** — `summary`, one outcome, ≤400 chars.
2. **A pointer** — `refs` into the real tree (`hosts` / `modules` / `tasks` /
   `docs`), validated at eval time, or a verbose body if nothing exists yet.
3. **An exit** — the command or artifact that will make the note untrue.

If you cannot name the file that will change or the task that will prove it,
you do not have a note yet; you have a conversation. Keep it out of the tree
until the first artifact is nameable.

| Rule | Enforced by |
| :--- | :--- |
| id `[a-z0-9-]`, known `kind`, known `status`, valid `priority` | `checks.<system>.agents-notes-schema` |
| `refs.hosts` names a real inventory host | same gate (eval-time check) |
| `refs.modules` / `refs.docs` paths exist on disk | same gate |
| `links` / `from` / `supersedes` name an existing note, once, not itself | same gate |
| `from`/`supersedes` form no cycle | same gate |
| `supersedes` target is marked `SUPERSEDED` | same gate |
| a `SUPERSEDED` note is claimed by some `supersedes` | same gate — no dead ends |
| note **with** refs → body ≤30 lines | same gate — the code is the detail |
| note **without** refs → body ≥6 lines | same gate — a leaf must carry intent |

## Start here when the task is novel

Before writing a note, ask the record whether the thing already exists — the
experiments are a design record, not a graveyard, and the cost of asking is about
a second (`nix eval` of the compiled index, then jq; no host eval).

```bash
task ops:notes:near Q="backups have never been restored"      # ranked, with lineage + refs
task ops:notes:lineage ID=restic-drill-through-unit           # ancestors, descendants, replacement
task ops:notes:task TASK=checks:build:route                   # why this task exists
```

`near` takes an intent, not keywords: stopwords are dropped and id/title/
summary/refs weigh more than a body hit, so "builds are too slow on the laptop"
returns the build-routing experiment rather than every note containing "slow".
Each hit prints `match n/total` — an honest confidence, not a ranking to obey.

Read the answer by **status**, because that is the difference between a solved
area and an open one:

| Hit | What it means | What to do |
| :--- | :--- | :--- |
| `DELIVERED`, has descendants | solved, and the solving was already extended | read the descendant and the `refs`; do not rebuild it |
| `DELIVERED`, no descendants | solved, nobody built on it | reference it, then decide: extend it (`from`) or leave it closed |
| `PROPOSED` / `OPEN`, refs | live work with an artifact | read `refs.tasks` first — the gate says how far it got |
| `PROPOSED`, leaf (no refs) | an idea owing a commit | promote it or `REJECTED` it with the reason; do not add a second leaf beside it |
| `REJECTED` | tried and killed | read the number that killed it before proposing the same thing |

An empty answer is a real answer: nothing in the record is near this intent, so
the first artifact you name becomes the note.

## Pick the kind by what can make it untrue

| You have… | `kind` | `status` | The exit is… |
| :--- | :--- | :--- | :--- |
| a hypothesis and a measurement | `experiment` | `PROPOSED` | the number that settles it |
| a design accepted, not started | `proposal` | `ACCEPTED` | a `priority` + a named gate |
| work in progress | `proposal` / `experiment` | `IN FLIGHT` | say exactly what is missing |
| one actionable outcome | `open` | `OPEN` / `BLOCKED` | a command that exits 0 |
| the queue's own rules / a closed cycle | `handoff` | `DELIVERED` | n/a — it is the record |
| standing policy, architecture shape | `reference` | `DELIVERED` | n/a — link the contract |

`BLOCKED` names the blocker (hardware, a UI action, another note id). `REJECTED`
keeps the number that killed it. `SUPERSEDED` links the replacement. A deleted
note is indistinguishable from an oversight, so never delete one to make room.

## Templates

Copy these into the `notes` attrset in `AGENTS.nix`. The `refs` block is the
part that turns an idea into something a future agent can find from the code.

### Experiment that will land in code

```nix
    exp-114 = {
      title = "Short imperative title";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "Hypothesis, and the measurement that would settle it.";
      from = ["exp-107"];                           # optional: the note this grew out of
      refs = {
        hosts = ["frieren"];                        # inventory names only
        modules = ["modules/services/thing.nix"];   # where the trying lives (must exist)
        tasks = ["checks:thing"];                   # the gate that will prove it (must exist)
        docs = [".agents/deploy/hosts/frieren.md"];
      };
      body = ''
        Hypothesis: …
        Measurement: `…` — record … .
        Exit: `checks:thing` is green; if it is not, set REJECTED with the number that killed it.
      '';
    };
```

> The `modules` entry is the promotion target. If the file does not exist yet,
> point at the file you will **modify** (a host module, `flake/checks.nix`), or
> write a leaf instead — never invent a path, the gate will reject it.

### Leaf experiment (no code exists yet)

```nix
    exp-200 = {
      title = "…";
      kind = "experiment";
      status = "PROPOSED";
      date = "2026-10-19";
      summary = "One sentence; no path exists yet, so the body carries the intent.";
      body = ''
        Intent: what this buys, for whom, on which host class.
        Constraints: hardware, power, existing services it would replace.
        Already rejected: … (and the reason).
        First artifact: create `modules/services/x.nix` behind `services.x.enable`,
          wire one host, then replace this leaf with a refs note in the same commit.
        Exit: … .
      '';
    };
```

A leaf is a debt of one commit: the moment the first artifact exists, add
`refs` and cut the body to ≤30 lines. A leaf that survives two cycles is rot —
either promote it or mark it `REJECTED` with the reason.

### Open todo

```nix
    open-thing = {
      title = "…";
      kind = "open";
      status = "OPEN";          # or BLOCKED — and then name the blocker in the body
      priority = "P2";          # P0..P6
      date = "2026-10-19";
      summary = "One outcome. If it has two exits, it is two notes.";
      refs = {
        hosts = ["eisen"];
        modules = ["hosts/eisen/llm-server.nix"];
        tasks = ["checks:host"];
      };
      body = ''
        Exit: `task checks:host HOST=eisen MODE=eval` exits 0 and the flag is deployed.
      '';
    };
```

No checkboxes. State is `status`, not `- [x]`, or the same item has two truths.

### Handoff and proposal

`kind = "handoff"` is queue **state**, not daily findings: queue rules, the
closed-cycle record, and the rule that `~/HANDOFF.md` is live host state written
by `agy-nightly-*`, never promoted by copying it into a note. It takes the same
shape, one line per landed change, each naming the module that carries it.

A `proposal` is an experiment that was accepted: same fields plus `priority`, and
a `body` that states the option surface and the exit criterion. Promotion is an
edit to that note, not a new document.

## Promotion ladder

```
leaf experiment (no refs, verbose intent)
  → experiment + refs to the module under trial + the measurement task
  → proposal/ACCEPTED (+ priority)                     ← design agreed
  → IN FLIGHT (+ refs.modules = what landed so far)    ← partial, be specific
  → DELIVERED (+ refs.modules = the landed module, refs.tasks = the gate)
  → one line in AUDIT.md, note stays as the design record
  → someone writes a note with from = [this]           ← provenance, not a tombstone
```

That last rung is the one that gets skipped, and skipping it is why a delivered
note is unreadable six months later: the module says *what* landed, only the
edge says *what it was an answer to*. Two fields, both new → old:

- `from` — this note exists because of that one (grew out of, closes, inspired
  by). Transitive: ancestry is a chain, and `ops:notes:lineage` prints it.
- `supersedes` — this note replaces that one; the gate then requires the target
  to be `SUPERSEDED`, and `replacedBy` is derived on the target. Never delete
  the replaced record: the rejection reason is the expensive part.

`links` stays for "same thread" with no order claimed. If you are unsure which
of the three you have, you have `links`.

The rung between "idea" and "delivered" is where slop forms. Two rules keep it
code:

1. **The note moves, the code appears.** A status change without a new
   `refs.modules` entry usually means nothing landed. Say what is missing in
   `body` instead of writing prose that sounds finished.
2. **The gate is named at authoring time.** `refs.tasks` must include the
   `checks:*` task that will prove the exit. If no such task exists, the first
   promotion step is creating it — a note whose exit cannot be executed is a
   wish.

## Anti-slop rules

- **Never graduate a note into a new markdown file.** `ARCHITECTURE.md`,
  `TODO.md`, `HANDOFF.md`, `EXPERIMENTS.md` are one-line stubs on purpose;
  `ops:docs:budget` fails if content creeps back. Delivered means
  `refs.modules` + `AUDIT.md` line.
- **Do not restate the code.** A traceable note gets ≤30 lines: the *why* and
  the exit. Option names, defaults and types belong in the module.
- **Do not paste measurements.** Keep the command that reproduces the number
  (in `body` or the deploy note), not a table that goes stale.
- **One outcome per note.** Two exit criteria = two notes with a `links` edge.
- **`summary` sells the decision, not the topic.** It is what `ops:notes`
  prints; "Investigate X" tells the next agent nothing.
- **Related notes use ids**, never titles — a rename must not orphan the edge.
- **Do not restate lineage in prose.** "This supersedes X" in `body` is a claim
  the gate cannot check; `supersedes = ["X"]` is the same sentence, checked.
- **Update `date` when status changes.** It is the only recency signal.

## Verify before you commit

```bash
task ops:notes:show ID=<id>                        # the note as the compiler sees it
nix eval --json .#agentsNotes.issues | toon -e               # [] = clean (0.2 s, no host eval)
nix build --builders "" .#checks.x86_64-linux.agents-notes-schema   # the gate
task ops:notes:lineage ID=<id>                     # from / supersedes / descendants / replacedBy
task ops:notes:module PATH=<path in refs.modules>  # reverse lookup: which notes touch this file
task ops:notes:task TASK=<task in refs.tasks>      # reverse lookup: why this task exists
task ops:notes:doc DOC=<path in refs.docs>         # reverse lookup: why this contract looks like this
```

All four reverse indexes (`:host`, `:module`, `:task`, `:doc`) are compiled from
the same `refs` block, so there is nothing to keep in sync by hand.

**Common trap:** a skill or runbook path stored under `refs.docs` is not found by
`ops:notes:module` — that task reads `refs.modules`. Keep the classification
honest: `refs.modules` is code you could edit; `refs.docs` is the contract that
explains it.

Then check the surfaces actually updated:

```bash
nix build --builders "" .#docs          # docs/generated/agents-notes/<id>.md
nix build .#fleet-docs-site             # data/agents-notes/<id>.json (site page)
```

## Where it renders

| Surface | How |
| :--- | :--- |
| markdown | `.#docs` → `docs/generated/agents-notes.md` + one page per note, refs as repo links |
| site | `.#fleet-docs-site` → Planner → **Agent notes (AGENTS.nix)**, one slice per note |
| query | `task ops:notes[:near\|:lineage\|:show\|:host\|:module\|:task\|:doc\|:search]` |
| code | `nix eval .#agentsNotes.{index,lineage,byHost,byModule,byTask,byDoc,byStatus,origins,frontier,open}` |

## Related

`knowledge-base` (where knowledge lives), `task-plane` (which task, and when not
to add one), `checks` (what each gate proves). Contract: `.agents/SCHEMA.md`
§2 and §5.
