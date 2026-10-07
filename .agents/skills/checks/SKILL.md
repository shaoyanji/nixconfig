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
| `checks:quick` | Narrow repo health checks (eval hosts, build host-architecture, nix lint, sops drift) |
| `checks:sops:drift` | Verify every sops file's embedded age recipients match `.sops.yaml` (catches un-rekeyed files before they break host activation) |

Per-host eval checks from the flake: `nix build .#checks.x86_64-linux.host-eval-<host> -L`.

## Nix linting & formatting

| Task | Description |
|------|-------------|
| `checks:nix:lint` | Run deadnix + statix on all nix files |
| `checks:nix:fix` | Auto-fix dead code, style, and formatting |
| `checks:nix:format` | Check formatting with alejandra (read-only) |

### experimental-features global wiring

Enable `nix-command` / `flakes` / `pipe-operators` in `modules/global/global.nix` under `nix.settings` — NOT the flake `nixConfig` block (that is for substituters/trusted keys only; `experimental-features` is a daemon-level setting). Validate after editing with `nix eval .#nixosConfigurations.<host>.config.networking.hostName --extra-experimental-features "nix-command flakes"`.

Pitfall: `nix.settings` uses shallow attrset merge (`//`), so a host-level `experimental-features = [...]` **replaces** the global list entirely. The legacy `extra-experimental-features` key is a separate attrset entry that appends — both can coexist on the same host. Check hosts that override `experimental-features` (e.g. `garnixMachine`, `testvm`) after changing the global default.

## Status

| Task | Description |
|------|-------------|
| `checks:status` | Show task list + git status |
