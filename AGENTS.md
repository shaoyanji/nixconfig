# AGENTS.md

**Nixconfig** — a Nix flake for NixOS, nix-darwin and Home Manager, across the hosts registered in
`inventory.toml`.

`Taskfile.yml` and `taskfiles/*` are the only executable truth. This file routes: it says where a
fact lives and what gate proves it. A fact with a compiler is queried, never copied here —
`.agents/SCHEMA.md` §1.

## Entry contract

1. **Start from intent.** `task help` → `task find:<word>` → the owning shard. Never invent a task
   name; a new one walks the ladder in the `task-plane` skill (eval → jq → Nix lib → check → task
   → script → Go).
2. **Truth order:** compiled data (`inventory.toml`, `modules.toml`) → host and module Nix →
   taskfiles → docs.
3. **Ask the compiler, not a pasted table.** `nix eval --json .#inventory.hosts | toon -e`
   (0.15 s), `.#agentSkills`, `.#agentsNotes`, `.#knowledgeGraph`,
   `task --list-all --json | jq -r '.tasks[].name'`, `nix build .#artifacts.docs`.
4. **Structural questions are the graph.** `task ops:kg:host|:skill|:doc|:tag|:module|:comention|:blast`
   answer "what touches X" from `.#knowledgeGraph`. Do not grep for structure.
5. **Facts are evaluated, not guessed.** Never evaluate a full host to answer a fact question;
   never run `nix flake check` here. Do not read `AGENTS.nix` in full: `task ops:notes*`,
   `nix eval .#agentsNotes… | toon -e`.
6. **Verification is phased:** eval to catch a config error · build to prove a closure · size to
   plan a build. Never check before a local rebuild — the switch is the check. A fix's gate is
   `checks:host` plus `warm-host.sh --check`; a build is for a change that adds derivations.
7. **This is a live host.** Bounded gates, one host per process, nothing top-level in the
   03:00–05:30 window, no ssh in unattended paths. `task ops:health` before blaming the config.
8. **Ask the record before you write.** `task ops:notes:near Q="<intent>"`, then
   `ops:notes:lineage ID=<id>`. Proposal or open work → an `AGENTS.nix` note (`agents-notes`
   skill); what happened → one xs turn; superseded narrative → `docs/history/`; procedure →
   `docs/` or a skill. No new root markdown file [[flake/policies.nix#root-markdown-closed]].
9. **The closed loop is real:** `fleet-sentinel` records jobs, generation age, disk and PSI every
   15 min; gatus pages on `[BODY].state != ok`. A green socket is not a successful job — read the
   ledger (`fleet-sentinel` skill).
10. **TOON is the IR.** JSON links the tools; TOON is its projection for an agent. TOML, YAML and
    Nix cross the boundary in their own tools (`yq -p toml -o json`, `nix eval --json`), never by
    hand. `task dev:toon:fix` recounts `[n]`; `checks:toon` and `checks:toon:surfaces` gate both.
11. **A source settles only the claims it is compiled for.** `nix eval --json .#epistemics.table |
    toon -e` says which source can settle which claim kind and where an answer is filed. Word
    overlap is not authority (`ops:wiki:ask KIND=` refuses first). Epistemics outranks policy.

## Agent turns (xs, mandatory)

The fleet turn log on delphi (`https://delphi.cloudforest-kardashev.ts.net:8449`, tailnet only) is
coordination state, not a chat relay, and it changes no merge authority. Read before a turn, post
one summary after:

```bash
task agents:xs:list Q="<words>"       # is someone already on this?
task agents:xs:post SUBJECT=nixconfig:<task-id> ACTION="one line" OUTCOME=done
```

`OUTCOME` is `done` | `in_progress` | `blocked: …` | `failed: …`; an unreachable endpoint queues the
body and replays it oldest-first. Summaries and identifiers only — the shim refuses
credential-shaped bodies, and there is no update or delete route. Schema, curl form and restore:
[`docs/agent-turns.md`](docs/agent-turns.md).

## Home initialization

1. **Repository root.** `~/Documents/nixconfig` (`frieren`: a symlink into `/Volumes/data`).
   `readlink -f` it first: where Home Manager owns the path it is a read-only store copy whose
   `git rev-parse` reports the active generation.
2. **`~/Taskfile.yml` is decrypted, not authored** — `modules/secrets/DE-Taskfile.yaml` via
   `task infra:secrets:decrypt:detaskfile-home` (every `infra:rebuild:*` runs it). It must stay a
   pure forwarder: a duplicate task name makes task reject the file (203), a `NIX_CONFIG` line
   breaks every `nix` call. Until it has run, use `task -t ~/Documents/nixconfig/Taskfile.yml …`.
   Declarative ownership is open work (`AGENTS.nix` note `taskfile-plane-handmade`).
3. **Guidance is materialized.** `~/.agents/` holds the skills and deploy notes; the host card and
   persona is `.#homeAgents.<host>` (`lib/home-agents.nix`), linked to `~/AGENTS.md` by activation.
4. **Secrets:** two encrypted files, two identity planes, one CA — [`docs/sops-rekey.md`](docs/sops-rekey.md).

## Architecture

```
flake.nix → flake-parts mkFlake → flake/outputs.nix
  ├── nixosConfigurations / darwinConfigurations / homeConfigurations  ← mkHost
  ├── packages · checks · devShells   ← flake/{packages,checks,devshells}.nix
  ├── nixFiles · modules              ← flake/nix-registry.nix
  └── docs · sites                    ← lib/docs.nix · lib/aki-site.nix
```

A host registers once in `flake/host-inventory.nix` (`kind`, `system`, feature list, module paths);
`outputs.nix` projects it by `kind`, so nothing is wired by hand. The module tree is `.#nixFiles`
(every tracked `.nix`, by path) and `.#modules` (every file under `modules/`, keyed
`profiles.base-node`), walked in `lib/nix-files.nix`; chains, hosts and modules name every import
(`self.modules."profiles.base-node"`), and `nix-registry` proves one name per file.

A host is a **feature list** (`base`, `nixos`, `dms`, `containers`, `impermanence`,
`macos`, `demo`, `home`), concatenated in order by `mkHost`; the seven `globalModules*` names are
derived aliases. The user role is a second feature list (`fleet.hmUserFeatures`: `systemd-policy`,
`shell`, `dev`, `ai`, `browser`, `media`, `desktop`) whose imports are taken or skipped as a whole,
because option surface is what a gate pays for. Chain table, with module counts:
`task docs:build` → `docs/generated/fleet-module-chains.md`.

Directories by role: `modules/global/` (chains), `profiles/` (host pieces), `services/` (a service
and its unit), `roles/` (user roles), `user/` (base, ai, desktop), `shell/`, `config/` (data and
dev shells). Constants such as the username live in `modules/global/user.nix` — import, never
hardcode. Profile, service and knob registry: `modules.toml`, rendered by `task docs:build` as
`modules-registry.md`; `task ops:kg:module PATH=<file>` is who imports it. There are no custom
packages: `.#artifacts`, `.#sites`, `.#servers`, `.#cli` only.

## Where a fact lives

| Asked for | Read |
| :--- | :--- |
| fleet catalog | `task docs:build` → `docs/generated/fleet-inventory.md` |
| knobs and profiles | same artifact → `modules-registry.md` |
| module chains | same artifact → `fleet-module-chains.md` |
| notes, decisions, open work | `task ops:notes` (source `AGENTS.nix`) |
| what touches what | `task ops:kg` (source `.#knowledgeGraph`) |
| the task contract | `task --list-all --json` (source `taskfiles/*.yml`) |
| what happened | `task agents:xs:list` |
| a procedure | `docs/*.md` or a skill |
| a superseded narrative | `docs/history/` |

Procedures, not facts: [`docs/task-control-plane.md`](docs/task-control-plane.md),
[`docs/nix-patterns.md`](docs/nix-patterns.md), [`docs/agent-contract.md`](docs/agent-contract.md),
[`docs/ci-pipeline.md`](docs/ci-pipeline.md), [`docs/storage-taxonomy.md`](docs/storage-taxonomy.md),
[`docs/sops-rekey.md`](docs/sops-rekey.md), [`docs/closure-reduction.md`](docs/closure-reduction.md),
[`docs/agent-turns.md`](docs/agent-turns.md), [`MANUAL.md`](MANUAL.md),
[`README.md`](README.md), [`hosts/microvms/README.md`](hosts/microvms/README.md),
[`.agents/SCHEMA.md`](.agents/SCHEMA.md), [`.agents/README.md`](.agents/README.md).

## Gates

```bash
task checks:quick              # repo hygiene; evaluates no host config (~22 s)
task check:list KIND=host      # the check inventory (taskfiles/checks.toml)
task check:leaf NAME=checks:prose · task check:host HOST=<h>
task checks:host HOST=<h>      # [gate] module system + assertions, one host
task checks:hosts HOSTS="a b"  # a named set, one process each
task checks:flake              # only where the machine can hold it
task checks:prose              # docs and skills carry no unslop vocabulary
task checks:nix:lint           # deadnix (fail) + statix (advisory)
```

**No `nix flake check` on a small host** [[flake/policies.nix#flake-check-memory-gated]]: it
evaluates every output in one process — 339.78 s / 6078.5 MiB / SIGKILL on this 11 GiB host.
`checks:flake` refuses below 16384 MiB. One host [[flake/policies.nix#no-fleet-default]], or a
named set under `scripts/task/oom-guard.sh` [[flake/policies.nix#sweeps-under-watchdog]].

**Phase 1, pre-build:** `checks:host` runs the module system and every assertion. A one-option eval
proves nothing; a toplevel `.drvPath` instantiates the whole graph (>120 s here) and is a CI
instrument. **Phase 2, build:** the build is the test, and never on the target host —
`task infra:warm:host:<host>`, then `task infra:deploy:host:<host>`. Fleet-wide warming is a weekly
schedule, not an ad-hoc sweep. **Phase 3, size:** `dev:closure:*` answers what is big and proves
nothing.

**A check must not spend build budget.** `frieren` has `eu.nixbuild.net` billed per build-second
(25 h/month): never `nix build` in a gate, and pass `--builders ""` when a check must shell out.
`nix eval --raw "<attr>.outPath"` plus `nix path-info --store <cache> <path>` asks the cache.
Offloading buys evaluation almost nothing — the module system is local; only a whole-gate CI run
moves the memory. `checks:host` flags: default `--builders ""`; `STRICT=1` substitute-or-fail;
`OFFLOAD=1` dispatch. Per-host limits are `compute_tier`/`allowed_tasks` in `inventory.toml`.

**Preserved hosts are not check targets** (`status = "preserved"`): dormant, sometimes known
broken. `warm-host.sh --check`, `infra:deploy` and `infra:apply` exit 0 before any eval;
`ALLOW_PRESERVED=1` revives. **Scope to the change:** host edit → that host; chain module → one host
per affected chain; `flake/` wiring → one host per kind, active only. Batch into one bash loop.
**Keyless environments** can eval (`nix eval`, `alejandra`, `deadnix`, `statix`), not
`checks:quick` (sops drift).

## Operating

```bash
task infra:plan:host:<host>     # substitute the closure, apply nothing
task infra:deploy:host:<host>   # gate → plan → apply → validate
task infra:rollback:host:<host> · task infra:logs:host:<host> UNIT=<unit>
task infra:rebuild:nixos        # switch IS the build (NOM=1 for the TUI); :darwin · :home-manager
task infra:sops:update-keys     # rekey every file after .sops.yaml changes
```

Rollback, journald `UNIT` defaults and NAS automount recovery: the `infra` skill and
`.agents/deploy/hosts/*.md`. `frieren` has its own rebuild topology (nightly window, one rebuild at
a time, origin-vs-local trap): `.agents/deploy/hosts/frieren.md`. Secrets, planes and CA:
[`docs/sops-rekey.md`](docs/sops-rekey.md) [[flake/policies.nix#secrets-are-encrypted]]
[[flake/policies.nix#ca-only-user-access]]. CI is inventory-driven with no matrix:
[`docs/ci-pipeline.md`](docs/ci-pipeline.md), [[flake/policies.nix#ci-matrix-is-inventory]].

Storage is `/srv/data` on `frieren` → `/Volumes/data`
[[flake/policies.nix#media-tree-isolation]]: [`docs/storage-taxonomy.md`](docs/storage-taxonomy.md).
The portable tool library is what non-Nix machines execute, so a fetch is static-only
[[flake/policies.nix#library-fetch-is-static]] and the tree mirrors to BurgerNAS
[[flake/policies.nix#library-crosses-the-wire]]; what the mirror carries is not on a schedule
[[flake/policies.nix#library-content-is-not-scheduled]]. A host path is pinned to the
submodules fetch — `nix build .?submodules=1#nixosConfigurations.<host>…`, never without it
[[flake/policies.nix#host-path-pinned-to-submodules]].

Publishing is task-driven and never edited on the host: `dev:site:*`, `neocities:*`, `envs:*`,
`dev:blog:*`, `docs:build`, `docs:site`. `task agents:menu` is the operator control plane and
`task menu` the whole-Taskfile TUI. A task is never `internal: true`
[[flake/policies.nix#task-surface-visible]].

## Adding a host

Module under `hosts/<name>/configuration.nix` (or `hosts/<name>.nix`), plus hardware or a profile
import; register `kind`, `system`, features and module paths in `flake/host-inventory.nix`; the
`kind` projection assembles it — `task infra:plan:host:<name>`. A new server's age key (from
`ssh_host_ed25519_key`) must be in `.sops.yaml` before `hashedPassword` decrypts; `ssh.ca.enable`
is inherited from `base-node.nix`.

## Docs, formatting, hooks

Content is markdown that Nix compiles into a store path: one pure projection per artifact, no second
renderer, nothing generated committed [[flake/policies.nix#generated-not-tracked]], and a rendered
surface is compiled from one registry rather than re-derived per vhost
[[flake/policies.nix#surfaces-are-compiled]]. Eval-time `readFile` is flake-scoped, so `git add`
an untracked `.md` before evaluating it.

`alejandra` is canonical; `statix` is advisory [[flake/policies.nix#statix-advisory]].
`scripts/task/nix-fmt.sh` is the one implementation behind `dev:fmt`, `checks:nix:fix`,
`checks:nix:lint`, `checks:nix:format` and the watcher, resolving versions from the `flake.lock`
pin. Four watch traps: killing the launching shell does not stop a grandchild, task's shell has no
`kill`, `--dry` still starts one, `watch: true` is CLI-only — always `task checks:nix:watch:stop`.
`.githooks/pre-commit` runs the hard gates and `.githooks/pre-push` what CI's docs job runs; enable
once with `bash .git-hooks-setup.sh`.

TOML goes through a format-aware tool [[flake/policies.nix#toml-through-a-tool]]: `yq -i -f
script.yq` applies nothing, so verify the compiled result. External fetches are registered in
`modules/config/fetches.json` and resolved by `lib/fetches-extra.nix`; `task dev:config:hash-update`
rewrites the hashes.
