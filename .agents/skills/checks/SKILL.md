---
name: checks
description: Validation and health checks — host evals, Nix linting and formatting, sops drift, repo health checks. Derived from taskfiles/checks.yml.
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

## Status

| Task | Description |
|------|-------------|
| `checks:status` | Show task list + git status |
