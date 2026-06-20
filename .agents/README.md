# Agent Guidance Index

## Skills (from Taskfiles)

Each taskfile shard has a corresponding skill under `.agents/skills/<name>/SKILL.md`:

| Skill | Source | Scope |
|-------|--------|-------|
| [`infra`](skills/infra/SKILL.md) | `taskfiles/infra.yml` | Host lifecycle, secrets, SOPS, store |
| [`agents`](skills/agents/SKILL.md) | `taskfiles/agents.yml` | Operator menu, xs, OAuth |
| [`checks`](skills/checks/SKILL.md) | `taskfiles/checks.yml` | Validation, smoke checks, nix lint |
| [`dev`](skills/dev/SKILL.md) | `taskfiles/dev.yml` | Git, flake, site, PRs, packages |
| [`services`](skills/services/SKILL.md) | `taskfiles/services-core.yml`, `services-legacy.yml` | Legacy wrappers |

## Routing

- **Tasks**: `Taskfile.yml` loads the `taskfiles/*` shards. Use `task --list-all` or `task help` to see namespaced entrypoints. See [Task Control Plane](docs/task-control-plane.md) for namespace policy and workflow examples.
- **Host lifecycle tasks**: Canonical operations live under `infra:*` (`taskfiles/infra.yml`). Legacy `services:*` names wrap to `infra:*` via `taskfiles/services-core.yml`.
- **Deploy guidance**: Start with `.agents/deploy/README.md`; per-host notes live in `.agents/deploy/hosts/*.md`.
- **Task routing**: `AGENTS.md` provides the top-level task namespace summary.

## Truth boundaries

- `taskfiles/*.yml` are the **executable truth**.
- `.agents/*` documents routing only — it never replaces the Taskfile.
- `scripts/task/*` are helper implementations, not entrypoints.
