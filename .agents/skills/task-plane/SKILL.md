---
name: task-plane
description: "Navigate the nixconfig task control plane by intent: which shard owns a question, cost tiers, what each gate proves, and when NOT to add a task or a script."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['tasks', 'navigation', 'control-plane', 'cost', 'refactor']
    related_skills: ['nix-eval', 'host-facts', 'checks', 'dev', 'infra']
---

# task-plane — find the task by intent, not by name

`task --list-all` prints every name in the tree. That is a wall, not a map. Start here:

```bash
task help                 # curated intent -> task map + live namespace counts (static, no nix)
task find:dns             # substring search over names AND descriptions
task --list-all --json | toon -e    # machine-readable: name, desc, aliases, location
```

Shards are the executable truth; this skill is the index. `taskfiles/README.md`
holds the per-file ownership map, `AGENTS.md` the operator manual.

## Ownership (which shard answers what)

| Intent | Shard / namespace | Notes |
| :--- | :--- | :--- |
| Host lifecycle: plan/apply/deploy/rollback/logs/warm | `taskfiles/infra.yml` (`infra:*`) | Canonical. `services:*` only wraps these. |
| Secrets, SOPS, store GC | `taskfiles/infra.yml` (`infra:sops:*`, `infra:store:*`) | Needs age keys — not keyless-safe. |
| Validation gates | `taskfiles/checks.yml` (`checks:*`) | Read the "what it proves" column below. |
| Git, flake updates, closure analysis, site deploy | `taskfiles/dev.yml` (`dev:*`) | `dev:closure:*` is build *preparation*. |
| Structural questions: what touches X | `taskfiles/ops.yml` (`ops:kg:*`) | Answered by the Elixir sidecar by default; `ops:kg:speed` measures it against jq. |
| "Has this been tried?" on a novel task | `taskfiles/ops.yml` (`ops:notes:near`, `ops:notes:lineage`) | ~1 s. The design record is data, so `qmd` cannot answer it. Do this before writing a note. |
| Canary MicroVM | `taskfiles/infra.yml` (`vm:canary:*`) | EXP-102. |
| Operator menus / gum TUIs | `taskfiles/agents.yml`, root `menu*` | |
| Legacy wrappers | `taskfiles/services-core.yml`, `services-legacy.yml` | `[deprecated]` only; never add here. |

## Cost tiers

| Tier | Examples | Cost |
| :--- | :--- | :--- |
| **free** | `task status`, `task help`, `task find:<x>`, `task checks:tasks`, `task checks:ports`, `dev:inventory:host` | < 1 s, local files only |
| **cheap (eval)** | `dev:inventory:json`, `dev:flake:get-hosts` | 0.1–2.5 s, no host config |
| **bounded (one host)** | `checks:host HOST=<h>` | ~13 s / 720 MiB per host, OOM-guarded |
| **HTTP probe** | `checks:build:route`, `checks:dns:failover` | bounded network request, no compile |
| **heavy / gated** | `checks:flake`, `infra:warm:host:<h>`, `infra:deploy:host:<h>`, `vm:canary:build` | builds, or refuses by design |
| **never a default** | `nix flake check`, any fleet sweep | 6 GiB / SIGKILL on this NAS |

## What each gate actually proves

| Task | Proves | Does **not** prove |
| :--- | :--- | :--- |
| `checks:tasks` | No duplicate task keys; every `task X` reference resolves (names + aliases, wildcards expanded) | That a task works |
| `checks:quick` | Repo hygiene: compiled inventory checks, task graph, lint, sops drift, modules.toml | **Any host config** — it forces no `nixosConfiguration`; not a pre-rebuild step |
| `checks:host HOST=<h>` | Module system + every assertion for ONE host (2035 assertions, ~13 s / 720 MiB) | That the closure builds |
| `checks:build:route` | Whether THIS host would have to compile (EXP-107) | That a build succeeds |
| `dev:closure:*` | What is big / duplicated / would be fetched | Nothing about correctness |
| `infra:warm:host:<h>` | Builder-side build + the cache serves the result | That the host activated it |

Note the removal: `checks:quick` used to run four
`config.networking.hostName` evals. They forced one option each and could not
fail on a real option-type error (EXP-114), so they were four nix processes of
zero proof. `checks:host` is the config gate.

## Cost discipline (do not regress this)

- **Do not run checks before a rebuild.** `task infra:rebuild:*` evaluates and
  builds the host; a pre-flight `checks:*` is a second evaluation for no extra
  proof. `checks:build:route` is the worst offender — it forces the whole
  toplevel (`drvPath`/`outPath`/`--dry-run`) and is CI/operator-only. It is no
  longer wired into any switch.
- **No task defaults to the fleet.** `checks:hosts` requires `HOSTS="a b"`.
  A default sweep is the footgun that got `nix flake check` SIGKILLed.
- **One host per process**, under `scripts/task/oom-guard.sh`. Peak memory is
  O(hosts forced in one process).
- **No ssh in an unattended path.** Tailscale SSH's browser check hung a run for
  5 minutes with no output (EXP-113). Ask the cache over HTTP instead.
- **A check that can build is not a check.** `--print-out-paths`, `nix build`
  without `--dry-run`, and `nixos-rebuild build` all compile.
- **A check that can hang is worse than no check.** Bound every network step with
  `--max-time`/`--timeout`.

## Adding a task (or not)

Add a task only when the thing is **repeatable and operator-facing**. Everything
else is the wrong shape:

| You want to… | Do this |
| :--- | :--- |
| Answer a one-off question about the config/registry | `nix eval` — see the `nix-eval` skill. No new task, no new script. |
| Read host facts | `dev:inventory:host` or `inventory.toml` — see `host-facts`. |
| Repeat a workflow a human would type twice a month | Add a task to the owning shard, with `desc` and a `summary` that names what it **does not** prove. |
| Wrap an existing task | Use `aliases:` (no `*` in an alias) or a `services:*` wrapper. Never copy the body. |

Task hygiene, enforced by `checks:tasks`:

- A duplicate key in the same shard is **silent** — YAML keeps the last one.
  (Found 2026-10-17: `dev:nixbuild:plan` and `dev:nixbuild:warm` were each
  defined twice in `taskfiles/dev.yml`.) A duplicate across shards is fatal at
  load (`task` exits 203, "Found multiple tasks").
- Every `cmds` line invoking `task <name>` must resolve. `checks:tasks` resolves
  names *and* aliases, expanding wildcard tasks.
- Give every task a `desc`; a task without one is invisible to `task --list`.
- Put the variable contract in `summary` (`HOST=`, `MODE=`, defaults, exit codes)
  so an agent does not have to read the shell body.

## The authoring contract (why most new tasks should not exist)

The control plane is already hundreds of tasks. Adding one is a maintenance bet that it
will be typed twice a month. Before writing a `cmds:` block, walk this ladder
and stop at the first rung that works:

| Rung | Instrument | Cost | When |
| ---: | :--- | :--- | :--- |
| 1 | `nix eval` on a flake attr | 0.1–2 s | a question about compiled data (`.#inventory`, `.#agentSkills`, `.#knowledgeGraph`) |
| 2 | `nix eval` on a caller-supplied expression | ~1 s | a one-off derivation/attribute question; no repo file needed |
| 3 | `jq`/`yq` over a compiled artifact | ms | projection, filtering, formatting |
| 4 | a **new Nix library** (`lib/*.nix`) | eval-time | a rule that must be true for every host/consumer |
| 5 | a `checks:*` gate | ~13 s (one host) | a regression that must fail a build |
| 6 | a task in an existing shard | seconds | a repeatable operator workflow |
| 7 | a shell script in `scripts/task/` | — | only the body of rung 6, never an entrypoint |
| 8 | a packaged Go binary | build | the thing ships to hosts or needs concurrency/robust parsing |

Anti-patterns found in this repo (do not repeat):

- **Python for glue that Nix already computes.** `compile-llm-specs.py` re-parses
  `inventory.toml` even though `lib/inventory.nix` has already compiled it. New
  context generation belongs in Nix; Python is legacy here.
- **A check that shells out to `nix build`.** It spends build budget as a side
  effect of looking. Use `nix eval --raw "<attr>.outPath"` + a cache query.
- **A task that fans out to the fleet by default.** `checks:hosts` requires a
  named set for a reason; `nix flake check` was SIGKILLed at 6 GiB.
- **Duplicating the body of another task.** Use `aliases:`, an `infra:*`
  canonical name, or a `services:*` wrapper.

Shard ownership now includes `taskfiles/ops.yml` (sentinel, ledger, skills
index, knowledge graph). Put observation tasks there, not in `checks.yml` — a
check must be able to fail a build; an ops task reports on a running system.

### Measured rung-1 costs (frieren, 2026-10-19)

| Command | Wall | Proves |
| :--- | ---: | :--- |
| `nix eval .#agentSkills.count` | 0.12 s warm / 1.2 s cold | skill tree parses + schema fields resolve |
| `nix eval .#inventory.hosts.fern.role` | 0.15 s | compiled registry, no host eval |
| `nix build .#checks.x86_64-linux."skills-schema"` | <1 s after eval | the gate is real (throw on violation) |
| `yq -r '.hosts.fern.role' inventory.toml` | 0.05 s | the raw field, **unvalidated** |

The eval is slower than `yq` because it validates and normalises. Use `yq` for a
single raw field, the eval whenever the answer must agree with what the fleet
deploys.

## Nav quick reference

```bash
task help                          # intent map
task find:closure                  # name+desc search
task checks:tasks                  # task-graph gate (free)
task checks:host HOST=frieren      # one host, all assertions
task dev:inventory:host HOST=fern  # host record, no host eval
task infra:deploy:host:fern        # plan -> apply -> validate
```
