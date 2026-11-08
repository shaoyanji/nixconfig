# Task control plane

This repository uses a simplified task namespace for predictable operator workflows.

## Current namespace structure

- `infra:*`: Host lifecycle operations (plan/apply/deploy/rollback/logs), secrets management, SOPS operations
- `agents:*`: Operator helpers and legacy operator menus
- `checks:*`: Validation and health checks (host evals, Nix lint/format, sops drift, flake transitive-input sweep)
- `dev:*`: Git workflows, flake updates, site deployment, and local development tasks
- `services:*`: Legacy compatibility wrappers (routes to `infra:*` tasks)

## Taskfile organization

- `Taskfile.yml`: Main entrypoint with top-level menus (deploy, logs, status, menu)
- `taskfiles/infra.yml`: Host lifecycle, secrets, SOPS operations
- `taskfiles/agents.yml`: Operator helpers, xs wrappers, OAuth management
- `taskfiles/checks.yml`: Validation and smoke checks
- `taskfiles/ops.yml`: Observation (`ops:health`, `ops:ledger`, `ops:sentinel:*`) and the compiled context plane (`ops:skills*`, `ops:kg*`, `ops:docs:budget`, `ops:bench:evals`). Ops tasks report on a running system; they must never be able to spend build budget.
- `taskfiles/dev.yml`: Git workflows, flake updates, site deployment
- `taskfiles/services-core.yml`: Minimal compatibility wrappers
- `taskfiles/services-legacy.yml`: Deprecated aliases (marked `[deprecated]`)

## Common workflows

### Host deployment
```bash
task infra:deploy:host:<host>    # Plan + apply + validate
task infra:plan:host:<host>      # Build/evaluate only
task infra:apply:host:<host>     # Apply configuration only
```

### Local rebuilds
```bash
task infra:rebuild:nixos         # Rebuild local NixOS host
task infra:rebuild:darwin        # Rebuild local Darwin host
task infra:rebuild:home-manager  # Rebuild Home Manager profile
```

### Git & flakes
```bash
task dev:git:quick-push          # Commit/push with AI-generated message
task dev:flake:update-complete   # Complete flake update workflow
task dev:flake:update:bountystash # Update single flake input
task dev:flake:update-transitive # Advance transitive pins a root update misses
task dev:nixbuild:plan           # Build/fetch gap report per host (read-only)
task dev:nixbuild:warm           # Remote-builder warm + cachix push (nixbuild.net budget)
task dev:qmd:refresh             # (Re)index repo markdown docs into local qmd
```

### Blog drafts
```bash
task dev:blog:draft TOPIC="…"    # ideas/<slug>.md scaffolded from the knowledge graph
task dev:blog:export SLUG=…      # publish it into the blog repo (never commits)
task dev:blog:mataroa            # the mataroa.blog ledger: local files vs the blog
```
The draft layer and its `about:` edges: [blog-drafting.md](./blog-drafting.md).
The mataroa.blog console (files first, the blog as a target):
[mataroa-console.md](./mataroa-console.md).

### Validation
```bash
task checks:quick                # Narrow repo HYGIENE (no host config evaluated)
task checks:tasks                # Task graph: Nix-compiled graph + name parity with `task`
task check:list KIND=host        # The check inventory, by kind, with live descriptions
task check:leaf NAME=checks:prose
task check:host HOST=<host>      # ONE host: module system + every assertion
task checks:flake:transitive     # Read-only transitive flake pin sweep (exit 1 on drift)
task checks:qmd:docs             # qmd docs collection exists + index fresh
```

### Three verbs over the check table
`taskfiles/checks.toml` holds one row per `checks:*` gate and its kind — `leaf`
(no input), `host` (one host), `cache` (asks a substituter). The command,
description and summary stay in the taskfile; the table owns only the kind,
which a taskfile cannot express. `check:leaf|host|cache` dispatch through it and
`check:list` renders it, so the listing is not a second index. `check:verify`
runs in `checks:quick`'s deps and fails both ways (a `checks:*` task with no
row, a row naming no task), which is what keeps the table from drifting after a
rename.

### Operator helpers
```bash
task menu                        # Task control-plane TUI (human view, gum)
task menu:operator               # Same plane, flat operator view
task menu:json                   # Whole plane as JSON (machine-readable)
task menu:list                   # Flat name<TAB>desc listing
task agents:menu                 # Curated themed operator menu
task inventory                   # Fleet inventory TUI
task modules                     # Control-knobs TUI
```

## Task control-plane TUI (`task menu`)

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

### Watch mode: stopping it is its own task

Watch mode leaves children running: the watcher is a *grandchild* of whatever
launched it. Killing the launching shell left a live `task checks:nix:watch`
formatting the repo for ~8 minutes, and it looked stopped because the parent PID
was gone. `task checks:nix:watch:stop` matches the watcher cmdline exactly (so it
can never signal the shell that launched it, or its own), signals it, waits, and
**verifies** it is gone instead of assuming the signal landed; by hand it is
`pkill -x task`, then `pgrep -x task`. Four traps, confirmed against task's own
watch docs:

- **A task's `cmds` run in task's restricted shell, not bash.** `kill` is an
  "unsupported builtin" there and silently does nothing — the stop task looked
  like it succeeded while the watcher kept running. Drop to a real shell for any
  non-POSIX builtin: `bash -c 'kill "$1"' _ "$pid"`.
- **`--dry` does not suppress `watch: true`.** `task --dry checks:nix:watch`
  starts a real watcher and blocks; there is no dry run for a watch task.
- **`watch: true` only applies to CLI invocations.** From another task's
  `cmds`/`deps` it does not start a watcher, so it cannot be pulled in as a
  dependency and quietly hang a pipeline.
- **`sources` drives change detection *and* the up-to-date check.** The watcher
  has no `generates`, so it re-runs on every change — correct for a formatter,
  and it writes nothing when there is nothing to change, which keeps it stable.

## The task graph, compiled (`scripts/task/lib/taskfile_graph.py`)

Taskfiles are YAML, and YAML **silently accepts** the failures a task graph
actually has: a duplicate key keeps the last definition and discards the first, so
an edit can vanish while every command exits 0 (it did — `dev:nixbuild:plan` and
`dev:nixbuild:warm` were each defined twice). `yq <file>` only proves the file
parses.

So the graph is compiled instead. `scripts/task/lib/taskfile_graph.py` walks
`Taskfile.yml` plus the nested include graph and emits one projection — task
names, `desc`/`summary`, `aliases`, `cmds`, `requires.vars`, wildcard arity,
cross-task references, include edges. **yq parses; the rules are the script.** No
IFD, no committed derivative, and no second source of truth: the shards are the
input and nothing is generated beside them.

```bash
python3 scripts/task/lib/taskfile_graph.py report   # names, files, every bucket
python3 scripts/task/lib/taskfile_graph.py by-name  # the read dispatchers use
python3 scripts/task/lib/taskfile_graph.py citations # contract page -> real tasks?
bash scripts/task/taskfile-graph.sh                 # [gate] all of the above + parity
```

The graph used to be compiled by `lib/taskfile.nix`, a hand-written YAML line
grammar, because `checks.<system>` needed it at eval time. That was a second
parser for a tree go-task already parses; it cost ~0.7 s per read, it needed a
committed digest pin before an edit was visible, and the two rules that genuinely
wanted eval time (`skills-task-mirror`, the contract-page citations) do not need
Nix at all. They are `scripts/task/skills-task-mirror.py` and the `citations`
mode now, so yq and go-task are the only YAML parsers left in the tree.

### Two layers, deliberately

| Layer | Owns | Why it must not move |
| :--- | :--- | :--- |
| the compiler | the **graph**: names, fields, references, includes | one parse, shared by the gate, the dispatcher and the registry |
| go-task | the **moment**: `{{.HOST}}`, `{{index .MATCH 0}}`, `{{.CLI_ARGS}}`, `{{if}}` | runtime values — the host is not known ahead of time |

596 template expressions live in this tree. Nothing in the compiler evaluates any
of them: the graph carries them as opaque strings.

### The oracle: go-task's own name set

A YAML reader cannot report a duplicate key it silently discarded, and it cannot
know which names go-task actually loads. So the gate has an oracle:
`task checks:tasks` compares the compiled name set against
`task --list-all --json`. The compiler is trusted exactly as far as `task` agrees
with it — a name only the compiler sees is parsed garbage, a name only go-task
sees is a task the graph is missing.

Duplicate keys are the one thing yq keeps hold of: it emits the pair stream, so
the `duplicate` bucket reads the key twice before Python's `dict` collapses it.

### Buckets: hard vs advisory

One flat list of "issues" is unreviewable, so violations are bucketed and each
bucket is either fatal or reported (`gateBuckets` in the compiler):

| Hard (fails `checks:tasks`) | Advisory (reported, never fatal) |
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
| a `task <name>` citation on `docs/agent-contract.md` that names nothing | |

The three budget buckets were **advisory until the tree fit**, then promoted: 28
summaries were over 600 characters (`checks:host` alone was 3400, and `ops:ask`
2629), which is a page an agent pays for on every `task --list-all --json` read.
They were rewritten to the contract — purpose, `VAR=` names, exit codes, and what
the gate does **not** prove — with the narrative dropped or left to `#` comments,
and the buckets moved into `gateBuckets`. A budget that is only reported is a
budget that drifts; `desc` is the one-line list label, `summary` is the contract,
`#` comments are for whoever reads the YAML next.

Two precision rules matter, both learned from a noisy first version that reported
34 "dangling" refs of which ~30 were English:

- A reference counts only in a **command position** — line start, or after
  `$({`, `&&`, `||`, `;`, `|`. `task keys` inside a `summary` is not a call. Prose
  mentions go to `proseRef`, which cannot fail a gate.
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
is `opaque` and passes — `checks:toml:lint` is exactly this shape.

### Every bucket is exercised

`tests/taskfile-graph/` violates every bucket exactly once, with its expected
verdicts in `tests/taskfile-graph/expected.json`. `checks:tasks` runs the fixture
on every invocation, so a bucket that stops firing — or starts firing on prose —
fails the gate instead of drifting. That selftest is what caught a nested
include's cycle being dropped (only the root level was reporting).

## Closure analysis (`dev:closure*`)

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

## Legacy migration

Many tasks in `services-legacy.yml` are marked `[deprecated]` and route to canonical `infra:*` or `dev:*` tasks. Prefer using the canonical namespaces directly for new workflows.
