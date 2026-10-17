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

## Quick checks

| Task | Description |
|------|-------------|
| `checks:quick` | Bounded repo HYGIENE: compiled inventory checks, task-graph integrity, nix lint, sops drift, modules.toml. **Evaluates no host config** — for that use `checks:host` |
| `checks:tasks` | Task-graph gate: duplicate task keys (YAML drops the first silently) and dangling `task X` references (names + aliases, wildcards expanded) |
| `checks:host:HOST=<host>` | **Per-host gate:** module system + all assertions + compiled `inventory.toml`, one host (~13 s, ~700 MiB) under the OOM watchdog |
| `checks:hosts HOSTS="a b"` | A **named set**, ONE AT A TIME, fresh process + watchdog each. `HOSTS` is required — there is no default and no fleet sweep, by design |
| `checks:host HOST=… MODE=eval` | One host, **evaluated** rather than built — arch-independent, and the way to check an aarch64 or darwin host from x86_64 |
| `checks:flake` | Runs `nix flake check` only where the machine can hold it; **refuses below 16 GiB RAM** |
| `checks:inventory:compiled` | Tier-1 inventory checks: schema consistency, flake coverage, module injection |
| `checks:sops:drift` | Verify every sops file's embedded age recipients match `.sops.yaml` (catches un-rekeyed files before they break host activation) |

**Never run `nix flake check` on a small host.** It evaluates every flake output — all
23 `nixosConfigurations` — in ONE process: measured 339.78 s, 6078.5 MiB peak, SIGKILL
(exit 137) on the 11 GiB NAS, leaving it at 62 % IO-stall. Memory is O(hosts forced in
one process); use `task checks:hosts` (sequential) and wrap anything heavy in
`scripts/task/oom-guard.sh`, which watches `/proc/vmstat oom_kill` and PSI every 10 s.

## Nix linting & formatting

| Task | Description |
|------|-------------|
| `checks:nix:lint` | Run deadnix + statix on all nix files |
| `checks:nix:fix` | Auto-fix dead code, style, and formatting |
| `checks:nix:format` | Check formatting with alejandra (read-only) |

### experimental-features global wiring

Enable `nix-command` / `flakes` / `pipe-operators` in `modules/global/global.nix` under `nix.settings` — NOT the flake `nixConfig` block (that is for substituters/trusted keys only; `experimental-features` is a daemon-level setting). Validate after editing with `nix-instantiate --parse modules/global/global.nix` (0.03 s, syntax) and then `task checks:host HOST=<a host on that chain>` (module system + every assertion, ~13 s / 720 MiB). Do **not** validate with `nix eval .#nixosConfigurations.<host>.config.networking.hostName`: it forces one option and type-checks nothing else (EXP-114).

Pitfall: `nix.settings` uses shallow attrset merge (`//`), so a host-level `experimental-features = [...]` **replaces** the global list entirely. The legacy `extra-experimental-features` key is a separate attrset entry that appends — both can coexist on the same host. Check hosts that override `experimental-features` (e.g. `garnixMachine`, `testvm`) after changing the global default.

## Status

| Task | Description |
|------|-------------|
| `checks:status` | Show task list + git status |
