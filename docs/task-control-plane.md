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
task checks:quick                # Run narrow repo checks
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
