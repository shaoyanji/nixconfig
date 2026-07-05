# AGENTS.md

`Taskfile.yml` plus the `taskfiles/*` shards are the canonical entrypoint for every executable task.

Use this document to orient yourself to the routing map; follow `taskfiles/README.md` for ownership and `.agents/README.md` for quick helper lookups.

`.agents/*` is guidance-only and never replaces the Taskfile truth. Each taskfile shard has a corresponding skill under `.agents/skills/<name>/SKILL.md` — see `.agents/README.md` for the full index.

## Task Namespace Summary
See [Task Control Plane](docs/task-control-plane.md) for full namespace definitions and workflow examples.

## Fast Reference

| Namespace | What | Skill |
|-----------|------|-------|
| `infra:*` | Host lifecycle, secrets, SOPS | `.agents/skills/infra/SKILL.md` |
| `agents:*` | Operator menu, xs, OAuth | `.agents/skills/agents/SKILL.md` |
| `checks:*` | Validation, smoke checks, nix lint | `.agents/skills/checks/SKILL.md` |
| `dev:*` | Git, flake, site, PRs, packages | `.agents/skills/dev/SKILL.md` |
| `services:*` | Legacy wrappers (canonical: `infra:*`) | `.agents/skills/services/SKILL.md` |

## Git Hooks Setup
This repo includes pre-commit hooks in `.githooks/` to catch common issues:
- `check-docs.sh`: Detects broken absolute paths in documentation

To enable: `bash .git-hooks-setup.sh` (sets `core.hooksPath` to `.githooks/`)

## Key Operator Helpers

- `agents:xs:*` wrappers run `scripts/task/xs-helper.sh` against local and service stores for artifact, contract, record, and trace work
- `agents:oauth:*` wrappers run `scripts/task/service-oauth.sh` with correct `HOME` and `XDG_*` environment for each service user
- NAS client recovery logic lives under `modules/profiles/nas-client.nix`

## Deployment Guidance

Host deployment flows use `infra:*` tasks directly:
- `infra:plan:host:<host>` - Build/evaluate host closure
- `infra:apply:host:<host>` - Apply configuration to remote host
- `infra:deploy:host:<host>` - Plan + apply + validate
- `infra:rollback:host:<host>` - Roll back to previous generation

See `.agents/deploy/README.md` for host-specific deployment notes.

## Build-Avoidance Guidance

Some services depend on packages that **build from source** (Maven, Go, etc.) and have no cached variant for overridden configurations. Common traps:

| Module | Line | Issue | Mitigation |
|--------|------|-------|------------|
| `services.tika` (`search/tika.nix`) | 82 | `cfg.package.override { enableGui = false }` produces uncached hash → Maven build | Inline systemd unit with stock `pkgs.tika` |
| `services.gotenberg` (`paperless.nix`) | — | Chromium stub at module level keeps ~300 MiB chromium out of closure | Configure `services.gotenberg.chromium.package` with stub |

Before deploying any host that references `services.*` modules for Java (Maven/Gradle), Go, or Rust packages, verify the final derivation is in the binary cache (`nix build --dry-run`) rather than building locally. Unnecessary local builds of large dependency chains (Maven, Chromium, LLVM) can take 10-60+ minutes on a thin host.
