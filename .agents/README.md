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

## Provenance and Home Initialization

- **Home Entrypoint**: When working from `$HOME` (`~`), `~/Taskfile.yml` provides tautological access to all commands in `~/Documents/nixconfig/Taskfile.yml` with `dir: ~/Documents/nixconfig` and `flatten: true`.
- **Repo Root**: `~/Documents/nixconfig` (symlink to `/Volumes/data/projects/nixconfig`).
- **Guidance & Skills**: Materialized in `~/.agents/` via Home Manager (`modules/user/ai/codex.nix`).
- **Canonical Manual**: `AGENTS.md` (and mirrored at `~/AGENTS.md`) is the unified manual for both agents and operators.

## Truth boundaries

- `taskfiles/*.yml` are the **executable truth**.
- `~/Taskfile.yml` forwards directly to `~/Documents/nixconfig/Taskfile.yml`.
- `.agents/*` and `AGENTS.md` document routing, fleet matrix, and runbooks.
- `scripts/task/*` are helper implementations, not entrypoints.
