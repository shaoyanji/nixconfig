# AGENTS.md

**Nixconfig** — a flake for NixOS, nix-darwin and Home Manager over the hosts in `inventory.toml`; `Taskfile.yml`
and `taskfiles/*` are the only executable truth, and this page names the query for a question, never the answer.

## Query, don't recite

A fact with a compiler is asked, not grepped, and never quoted from here.

```bash
task help · task find:<word>                        # task menu; finds a task's owning shard
task --list-all --json | jq -r '.tasks[].name'      # the whole task contract
nix eval --json .#inventory.hosts | toon -e         # fleet: hardware, status, network
nix eval --json .#agentSkills | toon -e             # skill index, one line each
nix eval --json .#agentsNotes | toon -e             # decisions, proposals, open work
nix eval --json .#knowledgeGraph | toon -e          # every node and edge
nix eval --json .#epistemics.table | toon -e        # which source settles which claim
nix eval --json .#proseBudget | toon -e             # line budget per page, with reasons
nix build .#artifacts.docs                          # every generated page
```

Structure is a graph query, never a grep: `task ops:kg:host|:skill|:module|:task|:tag|:doc|:comention|:blast`;
a procedure is a skill or a page in `docs/`, and the docs site's navigation comes from `.#knowledgeGraph`.

## Entry contract

1. **Intent first.** `router` names the shape and its ending gate; `task find:<word>` → the owning shard, and a
   new task walks the ladder (eval → jq → Nix lib → check → task → script → Go) [[flake/policies.nix#router-labels-are-routed]].
2. **Truth order:** compiled data (`inventory.toml`, `modules.toml`) → host and module Nix → taskfiles →
   docs. Never evaluate a whole host to answer a fact, and never `nix flake check` here.
3. **The switch is the check.** Do not gate before a local rebuild; a fix's gate is `checks:host` plus
   `warm-host.sh --check`, and a build is only for a change that adds derivations.
4. **This is a live host:** bounded gates, one host per process, nothing top-level between 03:00 and
   05:30, no ssh unattended, `task ops:health` before blaming the config.
5. **Ask the record before writing.** `ops:notes:near Q="<intent>"` then `ops:notes:lineage ID=<id>`; never read
   `AGENTS.nix` in full. New intent → an `AGENTS.nix` note (`agents-notes` skill), what happened → one xs turn,
   superseded narrative → `docs/history/`, a procedure → `docs/` or a skill [[flake/policies.nix#root-markdown-closed]].
6. **The closed loop is real:** `fleet-sentinel` logs jobs, generation age, disk and PSI every 15 min, and gatus
   pages on `[BODY].state != ok`; a green socket is not a finished job (read the ledger, `fleet-sentinel` skill).
7. **TOON is the agent boundary:** JSON links the tools, TOON is what a reader gets; TOML, YAML and Nix cross in
   their own tools (`yq -p toml -o json`, `nix eval --json`), never by hand. `task dev:toon:fix` recounts `[n]`,
   and `checks:toon` / `checks:toon:surfaces` gate both.
8. **A source settles only what it is compiled for:** `.#epistemics.table` says which source answers which
   claim and where an answer is filed. Word overlap is not authority; epistemics outranks policy.

## Agent turns (xs)

The xs turn log on delphi (`https://delphi.cloudforest-kardashev.ts.net:8449`) is the fleet's single coordination signal:
stewards consolidate polling here rather than polling git or chat. Turn logging is mandatory before and after work; it changes no merge authority.

```bash
# Before: check collisions (emits TOON), claim paths | After: done must name commit + passing gate
task agents:xs:list SUBJECT=nixconfig:<task-id> CLAIM="path/to/dir"
task agents:xs:post SUBJECT=nixconfig:<task-id> ACTION="claim: ..." OUTCOME=in_progress CLAIMS="path/to/dir" SOURCE=<agent>
task agents:xs:post SUBJECT=nixconfig:<task-id> ACTION="landed: ... | gate: checks:<name> PASS" OUTCOME=done COMMITS="<hash>" SOURCE=<agent>
```

`OUTCOME` is `done` (landed; names commit + gate) | `in_progress` (claim) | `blocked: <why>` (hard capability/credential stop only) | `failed: <why>` (gate failed; needs retry). `task agents:xs:list` emits compact TOON by default. Summaries only; offline queues to `~/.local/state/agent-turns/queue.jsonl`. Host `~/AGENTS.md` fans out from [`docs/agent-context/HOME-PREAMBLE.md`](docs/agent-context/HOME-PREAMBLE.md) (`task dev:inventory:home-agents`). Schema: [`docs/agent-turns.md`](docs/agent-turns.md).

## Where a fact lives

| Asked for | Run |
| :--- | :--- |
| fleet catalog, knobs, chains | `task docs:build` → `docs/generated/{fleet-inventory,modules-registry,fleet-module-chains}.md` |
| decisions, open work | `task ops:notes` (source `AGENTS.nix`) |
| what touches what | `task ops:kg` (source `.#knowledgeGraph`) |
| what happened | `task agents:xs:list` |
| memory/recall layers, authority per layer | `nix eval --json .#memoryLayers` |
| a procedure | `.agents/skills/*/SKILL.md`, then `docs/*.md` |
| an issue, before fixing it | its class → [`docs/issue-classes.md`](docs/issue-classes.md) |
| home init, docs pipeline, formatting, hooks | [`.agents/SCHEMA.md`](.agents/SCHEMA.md) §7 |

Long form: [`MANUAL.md`](MANUAL.md) (service map), [`docs/task-control-plane.md`](docs/task-control-plane.md), [`docs/nix-patterns.md`](docs/nix-patterns.md),
[`docs/agent-contract.md`](docs/agent-contract.md), [`docs/ci-pipeline.md`](docs/ci-pipeline.md), [`docs/sops-rekey.md`](docs/sops-rekey.md), [`docs/storage-taxonomy.md`](docs/storage-taxonomy.md), [`hosts/microvms/README.md`](hosts/microvms/README.md).

## Gates and operating

```bash
task checks:quick              # repo hygiene, evaluates no host config (~22 s)
task checks:host HOST=<h>      # [gate] module system + assertions, one host
task checks:hosts HOSTS="a b"  # a named set, one process each
task checks:flake              # only where the machine can hold it
task check:list KIND=host      # every other gate, and what it proves
task infra:deploy:host:<host>  # gate → plan → apply → validate; :plan substitutes only
task infra:rebuild:nixos       # the switch IS the build (NOM=1 for the TUI); :darwin · :home-manager
task infra:rollback:host:<host> · task infra:sops:update-keys
```

No `nix flake check` on a small host [[flake/policies.nix#flake-check-memory-gated]]; one host [[flake/policies.nix#no-fleet-default]], or
a named set under `scripts/task/oom-guard.sh` [[flake/policies.nix#sweeps-under-watchdog]]. Phase discipline and the flags (`STRICT=1`,
`OFFLOAD=1`) are the `checks` skill, and a gate never spends build budget — no `nix build` inside one, `--builders ""` when it
shells out. Scope to the change (host edit → that host; chain module → one host per chain; `flake/` wiring → one host per kind),
batch into one bash loop, and remember preserved hosts exit 0 before any eval (`ALLOW_PRESERVED=1` revives) while a keyless eval cannot run `checks:quick`.

Traps behind those flags, journald `UNIT` defaults, rollback and store maintenance: the `infra` skill and
`.agents/deploy/hosts/*.md`. Secrets, planes and CA: [`docs/sops-rekey.md`](docs/sops-rekey.md)
[[flake/policies.nix#secrets-are-encrypted]] [[flake/policies.nix#ca-only-user-access]]; CI is
inventory-driven [[flake/policies.nix#ci-matrix-is-inventory]]. Storage, the portable library and the
mirror rules: [`docs/storage-taxonomy.md`](docs/storage-taxonomy.md)
[[flake/policies.nix#media-tree-isolation]] [[flake/policies.nix#library-fetch-is-static]]
[[flake/policies.nix#library-crosses-the-wire]] [[flake/policies.nix#library-content-is-not-scheduled]];
a host path pins the submodules fetch [[flake/policies.nix#host-path-pinned-to-submodules]]. Publishing is
task-driven and never edited on the host; `task agents:menu` is the operator control plane; a task is
never `internal: true` [[flake/policies.nix#task-surface-visible]].

## Architecture

`flake.nix` → flake-parts mkFlake → `flake/outputs.nix`, which projects each host by `kind` (machine configs,
`packages`/`checks`/`devShells`, `nixFiles`/`modules`, `docs`/`sites`). A host registers once in
`flake/host-inventory.nix` as a **feature list** concatenated in order; `globalModules*` are derived aliases and
the user role is a second list (`fleet.hmUserFeatures`), because option surface is what a gate pays for.
`.#modules` is keyed `profiles.base-node` and `nix-registry` proves one name per file; directories are
`modules/{global,profiles,services,roles,user,shell,config}`, and constants live in `modules/global/user.nix` —
import, never hardcode. Chains and knobs are `task docs:build` output; no custom packages, only `.#artifacts`, `.#sites`, `.#servers`, `.#cli`.

A new host is a module at `hosts/<name>/`, registered there with its features, its age key from
`ssh_host_ed25519_key` in `.sops.yaml` before `hashedPassword` decrypts, proved by
`task infra:plan:host:<name>`.
