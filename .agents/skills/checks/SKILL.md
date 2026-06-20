---
name: checks
description: Validation and smoke checks — nullclaw/zeroclaw deployment validation, Nix linting and formatting, repo health checks. Derived from taskfiles/checks.yml.
---

# checks — Validation & Smoke Checks

Run validation and smoke checks for AI service deployments and Nix code quality.

## Quick checks

| Task | Description |
|------|-------------|
| `checks:quick` | Narrow repo health checks (eval hosts, build host-architecture, nix lint) |

## Nullclaw smoke checks

| Task | Description |
|------|-------------|
| `checks:nullclaw:smoke:<host>` | Smoke-check nullclaw via SSH (service, port, workspace, config, secret, health endpoint) |
| `checks:nullclaw:smoke:garnixMachine` | Config-file staging pattern |
| `checks:nullclaw:smoke:mtfuji` | Env-file pattern |
| `checks:nullclaw:smoke:thinsandy` | Direct env-file pattern |
| `checks:nullclaw:smoke:kellerbench` | On-demand host (unreachable = intentional power-off) |

Default params: port `3001`, bind `127.0.0.1`, workspace `/var/lib/nullclaw`, service `nullclaw`.

## Zeroclaw smoke checks

| Task | Description |
|------|-------------|
| `checks:zeroclaw:smoke:<host>` | Smoke-check zeroclaw deployment via SSH |

Default params: port `42617`, bind `127.0.0.1`, workspace `/var/lib/zeroclaw`, service `zeroclaw`.

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
