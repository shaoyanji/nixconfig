---
name: checks
description: "Validation, Nix lint, sops drift, repo health."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['checks', 'validation', 'nix', 'sops']
    related_skills: []
---

# checks — Validation & Health Checks

Run validation and health checks for host configs and Nix code quality.

> **Rebuild rule (2026-10-19).** Do **not** run a checks task before a local
> rebuild. `infra:rebuild:*` / `infra:switch:*` evaluates and builds the host;
> a pre-flight check is a second evaluation for no extra proof. In particular
> `checks:build:route` forces the whole host toplevel (`drvPath`, `outPath`,
> `nix build --dry-run`) and is **CI/operator-only** — it is no longer wired
> into any switch (`ROUTE_CHECK=1` opts in deliberately). Checks are for CI,
> a deliberate audit, or a remote deploy gate — not a rebuild ritual.

## Quick checks

| Task | Description |
|------|-------------|
| `checks:quick` | Bounded repo HYGIENE: compiled inventory checks, task-graph integrity, nix lint, sops drift, modules.toml. **Evaluates no host config** — for that use `checks:host` |
| `checks:tasks` | Task-graph gate: `lib/taskfile.nix` compiles the graph (duplicate keys, dangling refs, include cycles, orphan shards, `internal: true`, MATCH arity, an exit code a summary promises but its script never emits) and its name set must equal `task --list-all --json`; `checks.<system>.taskfile-graph` is the same rules as pure Nix (CI/keyless, exec + prose digests in the store name) |
| `checks:host:HOST=<host>` | **Per-host gate:** module system + all assertions + compiled `inventory.toml`, one host (~13 s, ~700 MiB) under the OOM watchdog |
| `checks:hosts HOSTS="a b"` | A **named set**, ONE AT A TIME, fresh process + watchdog each. `HOSTS` is required — there is no default and no fleet sweep, by design |
| `checks:host HOST=… MODE=eval` | One host, **evaluated** rather than built — arch-independent, and the way to check an aarch64 or darwin host from x86_64 |
| `checks:flake` | Runs `nix flake check` only where the machine can hold it; **refuses below 16 GiB RAM** |
| `checks:inventory:compiled` | Tier-1 inventory checks: schema consistency, flake coverage, module injection |
| `checks:kg:native` | Cold native graph build: median < 20 ms over 7 runs, **no subprocess in `KGEngine.Native`**, node/edge parity with the compiled projection |
| `checks:kg:canvas` | Builds `.#fleet-docs-site` locally and proves the knowledge-graph canvas works: every node has a slice, no dangling slice links, and headless Chrome **clicks a node** and must land on `fleet / knowledge-graph / host:frieren` |

**Preserved hosts are a warning, not a check.** A host with
`status = "preserved"` in `inventory.toml` is dormant, and some are known-broken
(cassini: a `homeDirectory` conflict that predates the current tree).
`warm-host.sh --check`, `checks:build:route`, `infra:deploy:host:*` and
`infra:apply:host:*` print the status and exit 0 **without evaluating anything**
— no `drvPath`, no `outPath`, no dry-run, no ssh. Do not "fix" a preserved host
because a check you ran on it failed; check or revive one only when the user
names it (`ALLOW_PRESERVED=1` for deploy).

**Never run `nix flake check` on a small host.** It evaluates every flake output — all
23 `nixosConfigurations` — in ONE process: measured 339.78 s, 6078.5 MiB peak, SIGKILL
(exit 137) on the 11 GiB NAS, leaving it at 62 % IO-stall. Memory is O(hosts forced in
one process); use `task checks:hosts` (sequential) and wrap anything heavy in
`scripts/task/oom-guard.sh`, which watches `/proc/vmstat oom_kill` and PSI every 10 s.

## Nix linting & formatting

`checks:nix:lint` is read-only and fails on deadnix, reports statix.
`checks:nix:fix` writes; `checks:nix:format` is `alejandra --check` alone. All
three run `scripts/task/nix-fmt.sh --tools …`, so they resolve tool versions from
the `flake.lock` pin rather than whatever is on `PATH`.

### experimental-features global wiring

Enable `nix-command` / `flakes` / `pipe-operators` in `modules/global/global.nix` under `nix.settings` — NOT the flake `nixConfig` block (that is for substituters/trusted keys only; `experimental-features` is a daemon-level setting). Validate after editing with `nix-instantiate --parse modules/global/global.nix` (0.03 s, syntax) and then `task checks:host HOST=<a host on that chain>` (module system + every assertion, ~13 s / 720 MiB). Do **not** validate with `nix eval .#nixosConfigurations.<host>.config.networking.hostName`: it forces one option and type-checks nothing else (EXP-114).

Pitfall: `nix.settings` uses shallow attrset merge (`//`), so a host-level `experimental-features = [...]` **replaces** the global list entirely. The legacy `extra-experimental-features` key is a separate attrset entry that appends — both can coexist on the same host. Check hosts that override `experimental-features` (e.g. `garnixMachine`, `testvm`) after changing the global default.

## Status

`checks:status` is the one check that proves nothing: it prints the task list and
`git status`. Use it to orient, never as evidence a change works.
