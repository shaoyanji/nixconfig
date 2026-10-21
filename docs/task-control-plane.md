# Task Control Plane

This repository uses a simplified task namespace for predictable operator workflows.

## Current Namespace Structure

- `infra:*`: Host lifecycle operations (plan/apply/deploy/rollback/logs), secrets management, SOPS operations
- `agents:*`: Operator helpers and legacy operator menus
- `checks:*`: Validation and health checks (host evals, Nix lint/format, sops drift, flake transitive-input sweep)
- `dev:*`: Git workflows, flake updates, site deployment, and local development tasks
- `services:*`: Legacy compatibility wrappers (routes to `infra:*` tasks)

## Taskfile Organization

- `Taskfile.yml`: Main entrypoint with top-level menus (deploy, logs, status, menu)
- `taskfiles/infra.yml`: Host lifecycle, secrets, SOPS operations
- `taskfiles/agents.yml`: Operator helpers, xs wrappers, OAuth management
- `taskfiles/checks.yml`: Validation and smoke checks
- `taskfiles/ops.yml`: Observation (`ops:health`, `ops:ledger`, `ops:sentinel:*`) and the compiled context plane (`ops:skills*`, `ops:kg*`, `ops:docs:budget`, `ops:bench:evals`). Ops tasks report on a running system; they must never be able to spend build budget.
- `taskfiles/dev.yml`: Git workflows, flake updates, site deployment
- `taskfiles/services-core.yml`: Minimal compatibility wrappers
- `taskfiles/services-legacy.yml`: Deprecated aliases (marked `[deprecated]`)

## Common Workflows

### Host Deployment
```bash
task infra:deploy:host:<host>    # Plan + apply + validate
task infra:plan:host:<host>      # Build/evaluate only
task infra:apply:host:<host>     # Apply configuration only
```

### Local Rebuilds
```bash
task infra:rebuild:nixos         # Rebuild local NixOS host
task infra:rebuild:darwin        # Rebuild local Darwin host
task infra:rebuild:home-manager  # Rebuild Home Manager profile
```

### Git & Flakes
```bash
task dev:git:quick-push          # Commit/push with AI-generated message
task dev:flake:update-complete   # Complete flake update workflow
task dev:flake:update:bountystash # Update single flake input
task dev:flake:update-transitive # Advance transitive pins a root update misses
task dev:nixbuild:plan           # Build/fetch gap report per host (read-only)
task dev:nixbuild:warm           # Remote-builder warm + cachix push (nixbuild.net budget)
task dev:qmd:refresh             # (Re)index repo markdown docs into local qmd
```

### Validation
```bash
task checks:quick                # Narrow repo HYGIENE (no host config evaluated)
task checks:tasks                # Task graph: Nix-compiled graph + name parity with `task`
task checks:host HOST=<host>     # ONE host: module system + every assertion
task checks:flake:transitive     # Read-only transitive flake pin sweep (exit 1 on drift)
task checks:qmd:docs             # qmd docs collection exists + index fresh
```

### Operator Helpers
```bash
task menu                        # Task control-plane TUI (human view, gum)
task menu:operator               # Same plane, flat operator view
task menu:json                   # Whole plane as JSON (machine-readable)
task menu:list                   # Flat name<TAB>desc listing
task agents:menu                 # Curated themed operator menu
task inventory                   # Fleet inventory TUI
task modules                     # Control-knobs TUI
```

## Task Control-Plane TUI (`task menu`)

`task menu` opens a Charmbracelet Gum TUI over the **whole Taskfile**. Both front
ends read one control-plane source — the Taskfile itself, via
`task --list-all --json` — so they can never drift apart:

| Entry | View | For |
| :--- | :--- | :--- |
| `task menu` | Human: themed, grouped by namespace, styled cards | humans browsing |
| `task menu:operator` | Operator: flat, filterable, exact task names | agents / scripts |
| `task menu:json` | `{source, task_count, tasks[]}` | machines |
| `task menu:list` | TSV `namespace<TAB>name<TAB>desc` | pipelines |

Backed by [`scripts/task/menu.sh`](../scripts/task/menu.sh). Add a task to any
`taskfiles/*.yml` and it appears automatically under a namespace-derived theme —
there is no second menu tree to maintain (contrast the hand-written `agents:menu`).

### Keep tasks visible to agents (`internal: true` is a trap)

`internal: true` removes a task from `task --list` **and** from
`task --list-all --json` — so it silently deletes tasks from the endpoint agents
read. It is not a human-visibility knob. Verified, not assumed:

| Mechanism | `task --list` | `task --list-all --json` |
| :--- | :--- | :--- |
| `internal: true` | hidden | **hidden too** — breaks every endpoint |
| no `desc`, has `summary` | hidden | present, `summary` intact |
| has `desc` | visible | present |

To keep a task off the human CLI while agents still see it, drop its `desc` and
move the text to `summary` — never `internal: true`.

### Wildcards need their match spliced in

`task 'infra:plan:host:*'` fails with `slice index out of range` (no `.MATCH` to
bind — this applies to agents invoking wildcards too). Use the concrete name
(`task infra:plan:host:poseidon`); the menu prompts for the value and splices it.

## The task graph, compiled (`lib/taskfile.nix`)

Taskfiles are YAML, and YAML is a data format with a parser that **silently
accepts** the failures a task graph actually has: a duplicate key keeps the last
definition and discards the first, so an edit can vanish while every command
exits 0 (it did — `dev:nixbuild:plan` and `dev:nixbuild:warm` were each defined
twice). `yq <file>` only proves the file parses.

So the graph is compiled instead: `lib/taskfile.nix` turns `Taskfile.yml` plus the
(nested) include graph into data — task names, `desc`/`summary`, `aliases`,
`cmds`, wildcard arity, cross-task references, include edges — and everything
else reads that one projection. `nix eval --json .#taskfileGraph.names` is the
cheap read; `.#taskfileGraph.version` is a digest of names + `cmds`.

### Two layers, deliberately

| Layer | Owns | Why it must not move |
| :--- | :--- | :--- |
| Nix | the **graph**: names, fields, references, includes | typed, shared, cheap to `nix eval`, and it can assert |
| go-task | the **moment**: `{{.HOST}}`, `{{index .MATCH 0}}`, `{{.CLI_ARGS}}`, `{{if}}` | runtime values — the host is not known at eval time |

596 template expressions live in this tree. Nix cannot evaluate any of them, and
trying would replace them with escaped literals: the graph therefore carries them
as opaque strings, and Nix-temporal vs go-task-temporal stays a hard split.

### Why a line grammar, not a YAML library

This nixpkgs pin has no YAML *reader* (only `lib.generators.toYAML`), and
import-from-derivation would make every eval that touches the graph build first.
A line grammar is only defensible if drift is loud, so the gate has an oracle:
`task checks:tasks` compares the parsed name set **and** the file list against
`task --list-all --json`. The grammar is trusted exactly as far as `task` agrees
with it — a name only Nix sees is parsed garbage, a name only go-task sees is a
task the graph is missing.

Indentation is **measured**, never assumed: the root file indents 4, every shard
indents 2, and a fixture in 2-space style exercises the root path. Assuming a
fixed width was the first version's bug — it parsed zero root tasks and reported
296 missing descriptions that were present all along.

### Buckets: hard vs advisory

One flat list of "issues" is unreviewable, so violations are bucketed and each
bucket is either fatal or reported (`gateBuckets` in the lib):

| Hard (fails `checks:tasks` and the flake check) | Advisory (reported, never fatal) |
| :--- | :--- |
| `duplicate` — same name defined twice | `nameGrammar` — outside `<ns>:<verb>[:<arg>]` |
| `danglingRef` — a `task <name>` call that does not resolve | `proseRef` — a `task <name>` in prose that does not exist (a `ns:*` family mention is fine) |
| `retiredRef` — calls a `[removed]`/`[deprecated]` task | |
| `includeCycle` — `task` refuses the tree (exit 110) | |
| `orphanShard` — a `.yml` no include edge reaches | |
| `longSummary` — `summary` > 600 chars (agent surface) | |
| `longDesc` — `desc` > 240 chars (`task --list` line) | |
| `noDesc` — neither `desc` nor `summary`: invisible to both surfaces | |
| `exitDrift` — a summary promises a code nothing in the task emits | `exitUnverified` — the claim rests on a `scripts/task/*.sh` not in the tree |
| `missingInclude`, `unflattened`, `internal`, `wildcardArity`, `sourcesWithoutWatch` | |

The three budget buckets were **advisory until the tree fit**, then promoted: 28
summaries were over 600 characters (`checks:host` alone was 3400, and
`ops:ask` 2629), which is a page an agent pays for on every
`task --list-all --json` read. They were rewritten to the contract — purpose,
`VAR=` names, exit codes, and what the gate does **not** prove — with the
narrative dropped or left to `#` comments, and the buckets moved into
`gateBuckets`. A budget that is only reported is a budget that drifts; `desc` is
the one-line list label, `summary` is the contract, `#` comments are for whoever
reads the YAML next.

Two precision rules matter, both learned from a noisy first version that reported
34 "dangling" refs of which ~30 were English:

- A reference counts only in a **command position** — line start (after the YAML
  dash), or after `$({`, `&&`, `||`, `;`, `|`. `task keys` inside a `summary` is
  not a call. Prose mentions go to `proseRef`, which cannot fail a gate.
- Resolution peels fixed arguments and matches wildcards **segment-for-segment**:
  `task checks:host:HOST=minyx` resolves to `checks:host`, `task
  infra:deploy:host:fern` matches `infra:deploy:host:*`. A prefix test accepted
  `dev:nixbuild:pl` as a call to `dev:nixbuild:plan`.

### Exit codes: the one clause prose can silently lose

A `summary` that promises an exit code is the sharpest part of the contract, and
it is the part that decays without a sound: when 28 over-budget summaries were
rewritten to fit, `checks:ports` lost `1 = STRICT drift` while the script kept
exiting 1. Nothing compared the sentence to the shell. Five rules make that
comparison a gate (`exitDrift`, fatal) without drowning it in false positives:

- a claim is `exit N` / `exits N` / `Exit N (…)`, **plus** `N = …` pairs in a
  summary that names an exit at all (`Exit 0 = clean, 1 = drift, 2 = unreadable`);
- a claim may name a **band** (`exit 130-137`): it holds when the task emits any
  code inside it, and both endpoints are parsed — the first version kept only
  the left edge, so `130-137` was silently the promise `130`;
- `0` is never a claim — every script can exit 0;
- a script emits every literal `exit N`, plus the repo's `fail=1 … exit "$fail"`
  idiom, which a literal-only scan called two *correct* summaries wrong;
- only the scripts and inline commands **the task itself** runs count, so a
  summary may describe another task's codes.

What it deliberately cannot judge: a task whose command is `nix build …` inherits
that tool's status. There is no code in the task to compare against, so the claim
is `opaque` and passes — `checks:toml:lint` is exactly this shape. Membership in
the tree is asked of `readDir`, not `builtins.pathExists`: on a lazy flake source
`pathExists` answers false for a path that is merely unrealised, which made the
first version report 20 existing scripts as missing.

### Versioning: minted by a gate, addressable after

```bash
task checks:tasks                       # graph + parity, ~1.2 s, builds nothing
nix eval --json .#taskfileGraph.version # digest of names + cmds (what executes)
nix eval --json .#taskfileGraph.proseVersion # digest of desc + summary (what agents read)
task checks:tasks ARTIFACT=1            # + the minted artifact (path, both digests, JSON hash)
OFFLOAD=1 task checks:tasks ARTIFACT=1  # same, built on /etc/nix/machines
STRICT=1 task checks:tasks ARTIFACT=1   # build nothing: "is this graph already built?"
task checks:quick                       # includes the check (with the selftest)
```

The three mode names are `checks:host`'s, deliberately: default never spends build
budget (`--builders ""`), `STRICT=1` is substitute-or-fail, `OFFLOAD=1` dispatches.
Two runs agree when they print the same path **and** the same `sha256` of
`graph.json` — an input-addressed derivation cannot yield two paths for one input,
so a disagreement means the input set moved (or a builder is nondeterministic).

The digests are **pinned** in [`flake/taskfile-digest-pin.nix`](../flake/taskfile-digest-pin.nix)
and compared by `checks.<system>.taskfile-digest-pin`, which the `docs-budget` CI
job builds on every push. A deliberate edit updates the pin in the same commit; an
unintentional one — a shard reformatted by a menu, a summary rewritten in bulk —
fails with both digests named instead of shipping as a silent change in what the
fleet executes or what an agent reads.

Measured 2026-10-21: the same graph minted here and on eu.nixbuild.net
(`taskfile-graph-<digest>`) gives one path and one hash; a deliberate `cmds` edit
produced a new digest, built cold on the builder in 2 s, and reverting returned
the original path. `nix build --rebuild` is how you would compare two builds of
the same derivation, and it **cannot be offloaded** — nix answers `local builds are
disabled (max-jobs = 0)`, because a trustable comparison has to run in the
reviewer's own sandbox. That is why the cross-machine claim rests on the path
being a pure function of the tree, not on a remote rebuild.

The name carries **both** digests — `taskfile-graph-<version>-p<prose>` — so what
executes and what an agent reads are both addressable, and the prefix tells you
which kind of change you are looking at. `version` excludes prose on purpose
(editing a `summary` must not look like a change in behaviour); `proseVersion` is
the same digest over `desc` + `summary`, so a prose-only edit still mints a
distinct, buildable path under the unchanged version. Measured 2026-10-21, one
summary reworded and reverted:

| edit | `version` | `prose` | path |
| :--- | :--- | :--- | :--- |
| baseline | `cae1cdc7ca6d` | `c0e18535aacf` | `…-taskfile-graph-cae1cdc7ca6d-pc0e18535aacf` |
| one summary reworded | `cae1cdc7ca6d` | `ce94226f319a` | `…-taskfile-graph-cae1cdc7ca6d-pce94226f319a` |
| reverted | `cae1cdc7ca6d` | `c0e18535aacf` | the original path, byte for byte |

`graph.json` now carries the prose surface **verbatim** (`prose`: name, shard,
`desc`, `summary` per task) as well as `version`/`proseVersion`, so an old build can
be diffed against a new one without a git checkout. Before that, the artifact held
only *findings about* prose — a violation count cannot tell you what it said.
A summary that trips a bucket (`proseRef`, `longSummary`) still mints a different
path at the same versions, because `violations` is in the artifact too.
`.#taskfileGraph` is pure (no `pkgs`, no host eval), so the same compile serves the
flake check, the gate script and any future generator.

The fixture `tests/taskfile-graph/` violates every hard bucket exactly once, and
`checks.<system>.taskfile-graph-selftest` asserts the expected verdicts — a bucket
that stops firing, or starts firing on prose, fails CI instead of drifting. That
selftest is also what caught a nested include's cycle being dropped (only the
root level was reporting) before it reached the tree.

Still hand-written, by design: the gating tasks. The generated artifact is data
(`graph.json` + `version` + `prose`), not a Taskfile — replacing the hand-written
YAML with generated YAML is the next stage, and it needs this parity layer first.

## Closure Analysis (`dev:closure*`)

Store-DB only — **no `nix eval`**, so it is cheap and works on any reachable host.
Targets the local `/run/current-system` by default, a remote host with `HOST=<name>`
(SSH-resolves the generation, then reads that host's store DB via `--store ssh://`),
or an explicit store path.

| Task | Output |
| :--- | :--- |
| `task dev:closure:size HOST=<name>` | total size + path count |
| `task dev:closure HOST=<name>` | subsystem breakdown (python, toolchain, …) |
| `task dev:closure:top N=20 HOST=<name>` | biggest contributors by own size |
| `task dev:closure:graph HOST=<name>` | subsystem breakdown as a terminal ASCII graph (Graphviz → `graph-easy`) |
| `task dev:closure:dot HOST=<name>` | raw Graphviz DOT (pipe to `dot`/`neato`) |
| `task dev:closure:toml HOST=<name> OUT=...` | 3-level tree (closure → subsystem → top packages) for handoff / agent-to-agent reports; lands in `docs/closures/` |
| `task dev:closure:tui` | interactive: pick a host, then a view |
| `task dev:closure:diff FROM=<old> TO=<new>` | closure size deltas (`nix store diff-closures`) — the module-reduction scoreboard |
| `task dev:closure:native` | same breakdown, computed natively by Nix (`pkgs.closureInfo`) — prototype |
| `task dev:closure:native:top` / `:graph` / `:toml` | the native counterpart of the matching store-DB view |
| `task dev:closure:native:diff` | **[gate]** verify the Nix-native graph matches `closure-analysis.sh` byte-for-byte |

Backed by [`scripts/task/closure-analysis.sh`](../scripts/task/closure-analysis.sh).
Generated report trees are written to `docs/closures/` — **gitignored**, since they
are point-in-time and go stale after any rebuild. Regenerate on demand, or keep a
snapshot attached to the specific handoff that needs it.

### Nix-native counterpart (`lib/closure-graph.nix`)

Milestone 4 of [`control-plane-vision.md`](./control-plane-vision.md): the same
five views, computed by Nix traversing its own store graph
(`pkgs.closureInfo` → `exportReferencesGraph`) instead of a shell loop over
`nix path-info`. Compared with the store-DB tool it is **cached** (the answer is
a store path), **reproducible**, and **diffable**, at the cost of being
local-store only — `closureInfo` builds locally, so there is no `HOST=<name>`.

`scripts/task/closure-graph-diff.sh` is the gate: it renders the same closure
from both implementations and diffs them. Parity is exact, not approximate —
including `numfmt`'s `--round=up` sizing and GNU `sort`'s tie-break rules, both
of which had to be reproduced deliberately.

## Legacy Migration

Many tasks in `services-legacy.yml` are marked `[deprecated]` and route to canonical `infra:*` or `dev:*` tasks. Prefer using the canonical namespaces directly for new workflows.
