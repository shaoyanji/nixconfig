# Agent contract: what done means for each kind of change

Routing lives in `AGENTS.md` (entry contract, task ladder) and the `task-plane`
skill. This page owns the part neither states: the exit predicate for each kind
of work, the evidence object a turn must carry, and the playbook declared before
the first tool call. A rule here that is not a `holds` in `flake/policies.nix` is
decoration, and this page is written to be as small as that rule allows.

## The door

| Question | Ask |
| :--- | :--- |
| what touches this host / doc / skill | `task ops:kg:host HOST=`, `task ops:kg:doc DOC=`, `task ops:kg:skill` |
| blast radius before a break | `task ops:kg:blast TARGET=` |
| which tasks exist, and their contract | `task --list-all --json`, `task find:<word>` |
| a host's role, arch, address | `nix eval --json .#inventory.hosts.<host>` (~0.15 s, no host eval) |
| does this config still hold | `task checks:host HOST=<host>` |
| what is big / what will be fetched | `task dev:closure:top`, `task dev:closure:diff`, `task dev:nixbuild:plan` |
| what happened, what is open | `task ops:notes:search Q=`, `task ops:ledger`, `task ops:health` |
| which turn is in flight | `task agents:xs:list` |

Every task named on this page resolves against the compiled graph: `task
checks:tasks` fails any `task <name>` citation here that the graph does not have
(wildcards resolve by their static prefix), so this table cannot drift into a
wish list.

### Where a lookup goes: name the pattern, or ask for one

A typed lookup is the default, and the edge caller is not it. Measured
2026-11-02: `task ops:kg:host HOST=fern` costs 145 ms, emits 40 bytes and is
exact; `task agents:call Q="what touches fern"` costs 1073 ms, emits 54 bytes and
reads 605 against 217, and gets the typed call right 3 times in 6 — the rest are
answered by the deterministic router that the caller falls back to anyway. If you
know the pattern, call it.

The caller earns its place only where the *phrasing* is what you don't know — and
then the Pareto split decides what belongs to you:

| the request is | it goes to | verdict |
| :--- | :--- | :--- |
| one lookup whose pattern you cannot name from the question | `task agents:call Q=` | `needle3` |
| more than one ask in the sentence | **you** split it, then send each part | `decompose` |
| a judgement or an operation (`why`, `how do I`, anything that builds) | **you**, with a budget | `reason` |

Exit 2 is the caller naming your quadrant, not a failure: read `pareto:` in the
body and act on it. For a run of prompts with no agent in the loop,
`task agents:call:batch` takes them on stdin and emits one JSON line per call
with its own `ms` and `gate` — that pipeline is the caller's justified use, and
why a slow step is named instead of fatal to the run.
[[flake/policies.nix#edge-caller-before-reasoning]]
[[flake/policies.nix#daemon-clears-kelly]]

**There is no generic `nix:eval` task, on purpose.** The ladder in the
`task-plane` skill is eval → jq → Nix lib → check → task → script → Go; a
catch-all eval task would be the shortest path to the whole-toplevel force that
[[flake/policies.nix#flake-check-memory-gated]] forbids. Evaluate the attribute
you actually need: `nix eval --raw .#nixosConfigurations.<host>.config.<option>`.

## Reading rule, scoped to structure

Learn structure from the graph and from evaluation, never from prose. Do not
read `AGENTS.nix` in full (query `task ops:notes`), do not re-derive the process
by reading `.agents/**`, and do not read a `.nix` comment to infer a default,
an ordering or a dependency — a comment can lie, `nix eval` cannot.

Reading is fine where the page *is* the procedure you were told to follow: the
runbook for the service being operated, the skill that owns the task, `AGENTS.md`,
`docs/*.md` you were pointed at. The distinction is **what you are trying to
learn**, not which file extension you touch.

## Declare the playbook first

One line before any tool call:

```
ROUTE <PLAYBOOK> :: <one-sentence goal> :: <hosts affected>
```

`FEATURE`, `DEBLOAT`, `DESLOP`, `INVESTIGATE`, `FLEET`. Unsure → `INVESTIGATE`.
Wrong → append `abandoned` and re-route; never switch silently mid-playbook.

## Exit predicates

### FEATURE — the closure contains the new behaviour

- `task checks:host HOST=<host>` exits 0 (module system + every assertion).
- The option evaluates to the intended value on that host.
- If the change adds derivations, a build is warranted — on a builder, not the
  target (`task dev:nixbuild:plan`, `task infra:warm:host:<host>`), and never
  from inside a check path.
- Behaviour exercised the way it will be used (a request, a unit, a test), not
  merely "it evaluates".

### DEBLOAT — the target has no consumers left

- Consumers proven from the graph (`task ops:kg:blast`) and, for a store object,
  `nix why-depends` on a `.drvPath` you already resolved.
- `task dev:closure:diff FROM=<old> TO=<new>` reports the negative delta.
- `task checks:host HOST=<host>` green — **not** `nix flake check`, which
  [[flake/policies.nix#flake-check-memory-gated]] reduces to a single host for
  exactly this reason.

### DESLOP — behaviour provably unchanged

- Diff touches comments, descriptions, or dead code only.
- `task checks:nix:format` and `task checks:nix:lint` report no new findings.
- `task checks:host HOST=<host>` green before and after.
- **Not** a hash of `config`: hashing the whole configuration is the toplevel
  force, `>120 s` with swap here, and the same spend `nixos-rebuild switch`
  already makes. If you believe behaviour changed, you are in FEATURE.

### INVESTIGATE — an answer, not an edit

- The answer cites at least one graph path and one evaluated attribute.
- No edits, no worktree, no rebuild. If it needs a change, it becomes FEATURE
  in a new turn.

### FLEET — one predicate per host, and a rollback

- Per-host exits from the playbook above, run one host per process.
- A named set under the watchdog, never "the fleet"
  ([[flake/policies.nix#no-fleet-default]]).
- The xs frame records `done` with the previous generation, so a rollback is a
  command and not an archaeology exercise.

## The evidence object

A turn that claims completion carries one record per predicate:

```json
{"cmd": "task checks:host HOST=frieren", "exit": 0, "artifact": "/nix/store/…", "predicate": "assertions + module system"}
```

No record → not done. This is the part a reviewer checks first, because it is
the only part that cannot be written from memory.

## Frames (xs)

The append-only store in `docs/agent-turns.md` is the coordination state. A
turn appends one frame with the schema it actually has: `subject`
(`<repo>:<task-id>`), `action`, `rationale`, `base_commit`, `branch`,
`files_changed`, `commits`, `claims`, `outcome` (`done` | `in_progress` |
`blocked: …` | `failed: …`). Post with `task agents:xs:post`; the shim rejects
unknown fields, and there is no update or delete, so a live claim is derived by
reading the tail — `task agents:xs:list` — not by mutating a record.

Before acting, read the stream for your subject. If a live claim overlaps your
scope, stop and report the collision instead of editing in parallel.

## Subagents

**Needle 3 is a tool caller.** It captures a sentence into a tool name plus typed
arguments (10/11 on the dispatch battery) and nothing more — the three quadrants
above are the only ones it may enter, and the rest is yours. A *label* — keep or
archive, tier 1 or 2 — is a classification, and it is not its job: three models
scored 3/10 on the keep/archive battery, so that decision is made by a rule and,
where judgement is genuinely needed, by Jev → Laya → Julia-1 (`decide`,
`/v1/systemone`). See `docs/mail-agent.md` for the measurement.

**A writer is not a reviewer.** The reviewer reads the frame and the diff against
a fixed rubric — does the evidence satisfy the stated exit, correctness risk,
secret exposure, worktree collision, anything claimed but unproven — and returns
PASS or FAIL. It never edits.

## Before you answer

- [ ] `ROUTE` emitted before the first tool call.
- [ ] Every factual claim backed by a task output or an evaluation, not a file read.
- [ ] Latest frame carries an evidence object.
- [ ] No rebuild or build path reached from inside a check.
- [ ] Playbook exit predicate satisfied, not approximated.
- [ ] If DEBLOAT/DESLOP: the closure delta or the format gate is quoted, not implied.
