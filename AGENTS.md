# AGENTS.md

**Nixconfig** — a Nix flake for NixOS, nix-darwin and Home Manager, across the hosts registered
in `inventory.toml`.

`Taskfile.yml` plus the `taskfiles/*` shards are the only executable truth. This file routes: it
says where a fact lives and what gate proves it. A fact with a compiler is queried, never copied
here — `.agents/SCHEMA.md` §1.

## Agent entry contract

1. **Start from intent.** `task help` → `task find:<word>` → the owning shard. Never invent a
   task name; a new one walks the ladder in the `task-plane` skill (eval → jq → Nix lib → check
   → task → script → Go).
2. **Truth order:** compiled data (`inventory.toml`, `modules.toml`) → host and module Nix →
   taskfiles → docs.
3. **Ask the compiler, not a pasted table.** `nix eval --json .#inventory.hosts` (0.15 s),
   `.#agentSkills` (1.2 s), `.#agentsNotes`, `.#knowledgeGraph`, `task --list-all --json`,
   `nix build .#artifacts.docs`. Two copies of a fact disagree within a month.
4. **Structural questions are the graph.** `task ops:kg:host HOST=`, `:skill`, `:doc`, `:tag`,
   `:module`, `:comention` and `:blast` answer "what touches X" from `.#knowledgeGraph`;
   `ops:kg:blast` is the reverse closure. Do not grep for structure.
5. **Facts are evaluated, not guessed.** Never evaluate a full host to answer a fact question;
   never run `nix flake check` on this host.
6. **Verification is phased:** eval to catch a config error · build to prove a closure · size to
   plan a build. Never run a check before a local rebuild — the switch is the check. The boot is
   the one thing a switch cannot prove: `checks:boot:self` on nixos, `checks:boot` for the rest.
   A fix's gate is `checks:host` plus `warm-host.sh --check`; a real build is for a change that
   adds derivations. Building the wrong *tree* voids the cache: `docs/nix-patterns.md` §"The gate
   for a fleet fix".
7. **This is a live host.** Bounded gates only, one host per process, no top-level evals during
   03:00–05:30, and no ssh in unattended paths. `task ops:health` before blaming the config.
8. **Ask the record before you write.** `task ops:notes:near Q="<intent>"`, then
   `ops:notes:lineage ID=<id>`, so an idea attaches to the one it grew out of. Then: proposal and
   open work → an `AGENTS.nix` note (`agents-notes` skill); what happened → one xs turn;
   superseded narrative → `docs/history/`; procedure → `docs/` or a skill. No new root markdown
   file [[flake/policies.nix#root-markdown-closed]].
9. **Do not read `AGENTS.nix` in full.** It is a ~5,500-line compiled data store. Query it:
   `task ops:notes[:host|:show|:search]`, `nix eval .#agentsNotes…` (0.2 s).
10. **The closed loop is real:** `fleet-sentinel` records jobs, generation age, disk and PSI
    every 15 min; gatus pages on `[BODY].state != ok`. A green socket is not a successful job —
    read the ledger.
11. **TOON is the IR.** JSON links the tools; TOON is its projection for an agent. TOML, YAML and
    Nix cross the boundary in their own tools (`yq -p toml -o json`, `nix eval --json`), never by
    hand. `task dev:toon:fix` recounts `[n]`; `checks:toon` and `checks:toon:surfaces` keep both
    rules true.
12. **A source may settle only the claims it is compiled for.** `nix eval --json
    .#epistemics.table | toon -e` (0.1 s) says which source can settle which claim kind, what to
    read instead, and where a settled answer is filed. Word overlap is not authority
    (`ops:wiki:ask KIND=` refuses before it spends a token). Epistemics outranks policy.

## Agent turns: the xs endpoint (mandatory)

The fleet turn log on **delphi** is coordination state, not a chat relay: it records who worked
on what, from which base commit, and what landed. It changes no merge authority.

`https://delphi.cloudforest-kardashev.ts.net:8449`, tailnet only; the token is a sops secret.

```bash
task agents:xs:list Q="<words>"      # before: is someone else on this?
task agents:xs:post SUBJECT=nixconfig:<task-id> ACTION="one line" OUTCOME=done
```

A post needs `SUBJECT`, `ACTION` and `OUTCOME` (`done` | `in_progress` | `blocked: …` |
`failed: …`); `RATIONALE`, `FILES`, `COMMITS`, `CLAIMS` and `SOURCE` are optional and `SOURCE`
should name the agent. An unreachable endpoint queues the body and replays it oldest-first; a
repeated UUID is a safe retry. Summaries and identifiers only — the shim refuses
credential-shaped bodies, and there is no update or delete route. Field schema, the curl form and
the restore procedure: [`docs/agent-turns.md`](docs/agent-turns.md).

## Home initialization

When a session starts from `$HOME`:

1. **Repository root.** `~/Documents/nixconfig` (on `frieren`, a symlink to
   `/Volumes/data/projects/nixconfig`). `readlink -f` it before trusting it: where Home Manager
   owns the path it is a read-only store copy whose `git rev-parse` reports the active generation.
2. **`~/Taskfile.yml` is decrypted, not authored.** It comes from the tracked
   `modules/secrets/DE-Taskfile.yaml` via `task infra:secrets:decrypt:detaskfile-home`, which
   every `infra:rebuild:*` also runs. It must stay a pure forwarder: a duplicate task name makes
   task reject the file (exit 203), and a `NIX_CONFIG` line there breaks every `nix` call. Until
   the decrypt has run on a host, use `task -t ~/Documents/nixconfig/Taskfile.yml …`.
   Declarative ownership is open work (`AGENTS.nix` note `taskfile-plane-handmade`).
3. **Guidance is materialized, not copied.** `~/.agents/` holds the skills and deploy notes. The
   host card plus persona is `.#homeAgents.<host>` (`lib/home-agents.nix`), linked to
   `~/AGENTS.md` by activation; refresh with `task dev:inventory:home-agents`.
4. **Secrets:** two encrypted files, two identity planes, one CA —
   [`docs/sops-rekey.md`](docs/sops-rekey.md).

## Architecture

### Flake assembly

```
flake.nix → flake/outputs.nix (the one assembly node)
  ├── nixosConfigurations  ← mkNixosHost (lib/mk-nixos-host.nix)
  ├── darwinConfigurations ← darwinSystem
  ├── homeConfigurations   ← homeManagerConfiguration
  ├── packages             ← flake/packages.nix (sites · artifacts · servers · cli)
  ├── checks · devShells   ← flake/checks.nix · flake/devshells.nix
  └── docs · sites         ← lib/docs.nix · lib/aki-site.nix
```

A host registers once in `flake/host-inventory.nix` (`kind`, `system`, chain, module paths);
`outputs.nix` projects it by `kind`, so nothing is wired by hand.

### Module chains

Seven baselines in `flake/module-sets.nix`; which host uses which is compiled, not tabled:
`nix eval --json .#inventory.hosts | jq '… .software.module_chain'`.

| Chain | What it is |
| :--- | :--- |
| `globalModulesNixos` | global + nixos + shared HM + sops + nix-index + dms + dank-greeter |
| `globalModulesRyoku` | global + nixos + sops + nix-index + ryoku (one shell per session) |
| `globalModulesContainers` | global + noDE + sops + Home Manager + nix-index (no desktop) |
| `globalModulesImpermanence` | `globalModulesNixos` + impermanence + disko |
| `globalModulesMacos` | global + macos + nix-homebrew + Home Manager + sops |
| `globalModulesDemo` | global + demo + Home Manager, no sops |
| `globalModulesHome` | standalone HM sharedModules + allowUnfree |

Two hosts compose their own chain in `flake/host-inventory.nix`: `ares` (containers +
impermanence) and `minyx` (global + determinate-nix + sops + raspberry-pi-3, no Home Manager).

### Where the modules are

`modules.toml` is the registry of profiles, services and knobs; `.#artifacts.docs` renders it as
`modules-registry.md`. Ask it instead of walking the tree:

```bash
task ops:kg:module PATH=modules/services/<name>.nix   # who imports it
nix eval --json .#inventory.hosts.<h>.software    # what this host actually runs
```

Directories by role: `modules/global/` (chains), `modules/profiles/` (reusable host pieces),
`modules/services/` (a service and its unit), `modules/roles/` (user roles: minimal, home, demo),
`modules/user/` (base, ai, desktop), `modules/shell/`, `modules/config/` (data and dev shells).
`modules/global/user.nix` holds the canonical user constants — import it, never hardcode `devji`.

### Packages

`.{sites,artifacts,servers,cli}` — no custom packages; the old `pkgs/` tree is gone.

## Commands

### Routing

```bash
task help                    # tasks grouped by namespace
task --list-all --json       # the discovery API: desc, summary, aliases, vars
task find:<word>             # tasks whose name or description matches
task status                  # git status + hostname
```

A task's `summary` carries its variable and exit-code contract. `internal: true` is banned (it
hides the task from the JSON API), wildcards are not invocable, and the compiled graph must match
`task --list-all --json` — `checks:tasks` asserts both.

### Notes and graph

```bash
task ops:notes:host HOST=<host>      # notes affecting a host
task ops:notes:show ID=<id>          # one note: summary, refs, exit criteria
task ops:notes KIND=open             # open backlog
task ops:notes:module PATH=<path>    # which notes touch this module
task ops:notes:task TASK=<task>      # why does this task exist
task ops:notes:search Q="<phrase>"
task ops:kg                          # graph stats and hubs
task ops:kg:host HOST=<host>         # inbound edges: skills and docs
task ops:kg:skill SKILL=<name>
task ops:kg:doc DOC=<path>           # hosts and skills documented in this file
task ops:kg:blast TARGET=<id>        # transitive dependents before a breaking edit
task ops:ask Q="what touches <host>"
```

### Host lifecycle and maintenance

```bash
task infra:plan:host:<host>       # substitute the closure; apply nothing
task infra:apply:host:<host>      # apply to the host
task infra:deploy:host:<host>     # gate → plan → apply → validate
task infra:rollback:host:<host>
task infra:logs:host:<host> UNIT=<unit>
task infra:sops:update-keys       # rekey every file after .sops.yaml changes
bash scripts/task/sops-drift-check.sh
```

Rollback, journald `UNIT` defaults and NAS automount recovery live in the `infra` skill and
`.agents/deploy/hosts/*.md`. `frieren` has its own rebuild topology (nightly window, one rebuild
at a time, origin-vs-local trap): `.agents/deploy/hosts/frieren.md`.

### Local rebuilds

```bash
task infra:rebuild:nixos          # switch IS the build; NOM=1 for the TUI
task infra:rebuild:darwin
task infra:rebuild:home-manager
```

### Git and flake

```bash
task dev:git:quick-push           # stage tracked, AI commit, push
task dev:git:ai-commit-push
task dev:git:quick-pull           # with submodules
task dev:flake:update-complete
task dev:flake:update-transitive  # inputs a root update misses
task dev:nixbuild:plan            # build/fetch gaps per host
task dev:nixbuild:warm            # build gaps on the builder, push to cachix (budget!)
task dev:closure:menu             # closure explorer (gum)
task dev:closure:reduce
task dev:qmd:refresh              # reindex docs + vault
```

### Data and storage

```bash
task data:audit                   # taxonomy, permissions, media hygiene
task data:clean:metadata          # ._*, .DS_Store
task data:clean:downloads
task data:protect:private         # 0700 and .nomedia shields
task data:index:refresh
```

### Closure analysis

Reads the store DB via `nix path-info`, no eval; `HOST=<name>` reads a remote host's store.

```bash
task dev:closure:size HOST=<name>     dev:closure        # total, then by subsystem
task dev:closure:top N=20             dev:closure:graph
task dev:closure:toml OUT=…           dev:closure:diff FROM=<old> TO=<new>
task dev:closure:native:diff       # [gate] Nix-native output == shell output
```

`lib/closure-graph.nix` is the Nix-native prototype (`pkgs.closureInfo` →
`exportReferencesGraph`); it is local-store only, and its roots must be declared. Report trees are
gitignored and stale after any rebuild. Rationale: `docs/control-plane-vision.md` §4/§6.

### Validation

```bash
task checks:quick                # repo hygiene; evaluates no host config
task checks:host HOST=<host>     # [gate] module system + assertions, ~13 s / 720 MiB
task checks:hosts HOSTS="a b"    # a named set, one at a time
task checks:flake                # only where the machine can hold it
task checks:prose                # docs and skills carry no unslop vocabulary
task checks:nix:lint             # deadnix (fail) + statix (advisory)
nix build .#hostChecks.<system>.<host> -L   # the same gate by attribute
```

### The flake-check memory rule

HARD RULE [[flake/policies.nix#flake-check-memory-gated]]: `nix flake check` evaluates every flake
output in one process — measured 339.78 s / 6078.5 MiB / SIGKILL on this 11 GiB host.
`task checks:flake` refuses below 16384 MiB. Check one host
[[flake/policies.nix#no-fleet-default]] or a named set under `scripts/task/oom-guard.sh`
[[flake/policies.nix#sweeps-under-watchdog]], which polls `oom_kill`, memory/IO PSI and
`MemAvailable` over the whole process group and kills the run on pressure.

### Verification protocol

**Phase 1 — pre-build: one bounded gate.** `nix build .#hostChecks.<system>.<host>` runs the
module system and every assertion (13.16 s / 720 MiB). A one-option eval proves nothing; a
toplevel `.drvPath` instantiates the whole graph (>120 s here) and is a CI instrument, not a
per-edit step. On a local rebuild, run no check first — the switch forces the same graph.

**Phase 2 — build: the build is the test.** Once a change alters the closure, evaluation is no
longer evidence. Never build on the target host:

```bash
task infra:warm:host:<host>     # build elsewhere, verify the cache serves it
task infra:deploy:host:<host>   # one intended host: gate → plan → apply → validate
```

Fleet-wide building is a schedule (`fleet-warm-cache`, weekly on `frieren`), never an ad-hoc
sweep.

**Phase 3 — size and shape are build preparation,** not verification: `dev:closure:top`, `:size`
and `:reduce` answer "what is big, what will be fetched" and prove nothing.

**A check must not spend build budget.** `frieren` has `eu.nixbuild.net` configured, billed per
build-second against 25 h/month. Never call `nix build` in a gate; when a check must, pass
`--builders ""` (as `warm-host.sh` and `checks:host` do). `nix eval --raw "<attr>.outPath"` plus
`nix path-info --store <cache> <path>` asks the cache without building.

**What offloading buys:** almost nothing for evaluation. Measured on frieren 2026-10-20: the host
gate is 10.56 s / 958 MiB locally and 12.68 s / 746 MiB offloaded, of which the remote build is
746 ms — the cost is the local module system and its 1961 assertions. Only a whole-gate CI run
(`task dev:ci:trigger:<host>`, which builds the host and its `hostChecks` and pushes both to
cachix) actually moves the memory. `checks:host`'s flags: default `--builders ""`;
`STRICT=1` substitute-or-fail; `OFFLOAD=1` dispatch deliberately.

**Never put ssh in an unattended path** — a browser check on Tailscale SSH hung a run for five
minutes. Ask the cache over HTTP instead (`scripts/task/warm-host.sh`). **When a build is needed,
warm it elsewhere:** a `nixos-rebuild build` on a 2c/4t host was killed at load 9.4; the same
closure on CI took 6m53s and left a substitution-only rebuild. Per-host limits are declared in
`inventory.toml` (`compute_tier`, `allowed_tasks`). This is `exp-107`/`exp-113`; the gate is
`task checks:build:route`.

- **Preserved hosts are not check targets** (`status = "preserved"`): a dormant failure is not
  this run's regression. `warm-host.sh --check`, `infra:deploy` and `infra:apply` exit 0 before
  any eval; `ALLOW_PRESERVED=1` revives.
- **Scope to the change:** host edit → that host; chain module → one host per affected chain;
  `flake/` wiring → one host per kind, active only. Batch into one bash loop.
- **Keyless environments** can eval: `nix eval`, `alejandra --check`, `deadnix`, `statix check`.
  Not keyless: `checks:quick` (sops drift), any `infra:*` secret task.

### Secrets and SOPS

```bash
task infra:secrets:edit:secrets   # sops secrets file
task infra:secrets:edit:apikeys
task infra:secrets:edit:taskfile
task infra:sops:get:*             # query one value
task infra:sops:fzf               # pick an env entry
task infra:sops:update-keys       # rotate recipients
```

Planes, anchors, CA and the rekey procedure: [`docs/sops-rekey.md`](docs/sops-rekey.md)
[[flake/policies.nix#secrets-are-encrypted]] [[flake/policies.nix#ca-only-user-access]].

### Publishing

Every publishing surface is driven from this repo's taskfiles; none is edited on the host.

```bash
task dev:site:list                # deployment targets from the manifest
task dev:site:deploy -- <target>  # build + deploy one
task neocities:menu               # blog control plane; neocities:deploy verifies round-trips
task envs:build                   # markdown → HTML, gemtext, gopher, finger (strict)
task envs:publish                 # all four targets, old web root moved aside
task dev:blog:mataroa             # mataroa console ledger, local markdown vs the blog
task docs:build                   # generated markdown tree (store path only)
task docs:site                    # the rendered docs site
```

`envs:build`/`envs:publish` read the site repo (`~/Documents/envsdotnet`, `ENVS_SITE_REPO` to
override) and build locally; nothing builds on the pubnix any more. `dev:blog:export` writes a Jekyll
post into the blog repo and never commits.

### TOTP (cloak)

```bash
task dev:cloak:list               # accounts
task dev:cloak:view               # pick one and print the code
task dev:cloak:edit
task dev:cloak:sync-bw -- ./export.json
```

### Operator menu

```bash
task agents:menu                  # operator control plane
task menu                         # the whole Taskfile as a gum TUI
```

A task is never `internal: true` — that breaks the JSON surface
[[flake/policies.nix#task-surface-visible]].

### Raw Nix

```bash
nix build .?submodules=1#nixosConfigurations.<host>.config.system.build.toplevel  # NEVER drop ?submodules=1 [[flake/policies.nix#host-path-pinned-to-submodules]]
nix build .#hostChecks.<system>.<host> -L
bash scripts/task/oom-guard.sh --timeout 3 -- nix eval --raw .#inventory.hosts.fern.role
nix build .#devShells.<system>.default
alejandra <file> || alejandra --check <file>
```

## Storage

`/srv/data` on `frieren` → `/Volumes/data`: [`docs/storage-taxonomy.md`](docs/storage-taxonomy.md)
[[flake/policies.nix#media-tree-isolation]] [[flake/policies.nix#library-content-is-not-scheduled]]

The portable tool library (`bin-*`, `appimages`) is what non-Nix machines execute, so linkage is
the contract: a fetch is static-only [[flake/policies.nix#library-fetch-is-static]], and the tree
mirrors to BurgerNAS [[flake/policies.nix#library-crosses-the-wire]] (`task data:library`).

## CI

Inventory-driven, no matrix: [`docs/ci-pipeline.md`](docs/ci-pipeline.md)
[[flake/policies.nix#ci-matrix-is-inventory]]. CI builds each host and its `hostChecks` and pushes
both to cachix; the fleet is CI's job, not this host's.

## Nix gotchas

Traps, patterns and agent failure modes: [`docs/nix-patterns.md`](docs/nix-patterns.md).

HARD RULE [[flake/policies.nix#toml-through-a-tool]]: TOML through a format-aware tool;
`yq -i -f script.yq` applies nothing, so verify the compiled result.

## Adding a host

1. Module under `hosts/<name>/configuration.nix` (or `hosts/<name>.nix`), with hardware or a
   profile import as needed.
2. Register in `flake/host-inventory.nix`: `kind` (nixos/darwin/home), `system`, chain, module
   paths, `specialArgs` as needed.
3. The `kind` projection assembles it; build with `task infra:plan:host:<name>`.

A new server's age key (from `ssh_host_ed25519_key`) must be in `.sops.yaml` before
`hashedPassword` decrypts; `ssh.ca.enable` is inherited from `base-node.nix`.

## Memory and search

| Layer | Role | When |
| :--- | :--- | :--- |
| `MEMORY.md` | boot memory, persists | always loaded |
| vault | fast working memory, offline | first stop |
| qmd wiki | docs, runbooks, codebase | concept/location queries |
| mem0 / supermemory | deep consult | jev decides (min-prob 0.8, min-margin 0.15) |
| ZIM shelf | world knowledge, no quota | a question about the world |

Search order: vault → qmd BM25 → graph → mem0 (jev-decided) → ZIM shelf
(`task ops:wiki:ask Q=…`, then the rate-limited web).

```bash
task dev:qmd:refresh             # docs + vault
task checks:qmd:docs             # registered and fresh
qmd search "impermanence disko" -c nixconfig
qmd search "query" --json | toon -e
```

The `nixconfig` collection masks `**/*.{nix,md}`, so a code comment and the page explaining it are
one query apart. Vectors are optional: [`docs/qmd-embedding-offload.md`](docs/qmd-embedding-offload.md).

## Compiled documentation

There is no hand-kept file map here: the compiled surfaces are the map.

| Asked for | Read |
| :--- | :--- |
| fleet catalog | `nix build .#artifacts.docs` → `docs/generated/fleet-inventory.md` |
| knobs and profiles | same artifact → `modules-registry.md` (`modules.toml` is the source) |
| notes, decisions, open work | `task ops:notes` (source: `AGENTS.nix`) |
| structure: what touches what | `task ops:kg` (source: `.#knowledgeGraph`) |
| the task contract | `task --list-all --json` (source: `lib/taskfile.nix`) |
| what happened | `task agents:xs:list` (source: the xs store) |
| a procedure | `docs/*.md` or a skill |
| a superseded narrative | `docs/history/` |

Start points that are procedures rather than facts: [`.agents/SCHEMA.md`](.agents/SCHEMA.md)
(doc and skill contract), [`docs/task-control-plane.md`](docs/task-control-plane.md),
[`docs/agent-contract.md`](docs/agent-contract.md), [`docs/nix-patterns.md`](docs/nix-patterns.md),
[`docs/agent-turns.md`](docs/agent-turns.md), [`README.md`](README.md),
[`MANUAL.md`](MANUAL.md), [`hosts/microvms/README.md`](hosts/microvms/README.md).

Documentation is content that Nix compiles into a store path: one pure projection per artifact, no
second renderer, nothing generated committed [[flake/policies.nix#generated-not-tracked]]. Content
stays in markdown, CSS/JS in files the derivation reads, and a rendered surface is compiled from
one registry [[flake/policies.nix#surfaces-are-compiled]]. Eval-time `readFile` is flake-scoped:
`git add` an untracked `.md` before evaluating it.

## Formatting and hooks

`alejandra` is canonical; `statix` is advisory and never auto-applied
[[flake/policies.nix#statix-advisory]]. `scripts/task/nix-fmt.sh` is the single implementation
behind `dev:fmt`, `checks:nix:fix`, `checks:nix:lint`, `checks:nix:format` and the watcher — it
takes `--tools deadnix,statix,alejandra` and resolves versions from the `flake.lock` pin, cached
under `~/.cache/nixconfig-nixfmt/`.

```bash
task checks:nix:fix      # deadnix + alejandra, write
task checks:nix:lint     # read-only gate: deadnix fails, statix reports
task checks:nix:format   # read-only: alejandra --check
task checks:nix:watch    # auto-format dirty files; stop with checks:nix:watch:stop
```

Four watch traps: killing the launching shell does not stop a grandchild watcher, task's shell has
no `kill`, `--dry` still starts one, and `watch: true` is CLI-only. Always
`task checks:nix:watch:stop`.

`.githooks/pre-commit` runs the hard gates; `.githooks/pre-push` runs what CI's doc job runs
(`scripts/task/docs-budget.sh`, `scripts/task/prose-tells.sh`, the digest pin). Enable once with
`bash .git-hooks-setup.sh`. A missing tool is fetched from the pinned nixpkgs, so the hook behaves
the same on every machine.

## Fetched dependencies

External fetches are registered in `modules/config/fetches.json` and resolved by
`lib/fetches-extra.nix`; update hashes with `task dev:config:hash-update` (it runs
`scripts/task/nix-hash-update.sh`).
