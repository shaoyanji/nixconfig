# Agent Guidance Index

- **Tasks**: `Taskfile.yml` loads the `taskfiles/*` shards. Use `task --list-all` or `task help` to see namespaced entrypoints. See [Task Control Plane](docs/task-control-plane.md) for namespace policy and workflow examples.
- **Host lifecycle tasks**: Canonical operations live under `infra:*` (`taskfiles/infra.yml`). Legacy `services:*` names wrap to `infra:*` via `taskfiles/services-core.yml`.
- **Deploy guidance**: Start with `.agents/deploy/README.md`; per-host notes live in `.agents/deploy/hosts/*.md`.
- **Task routing**: `AGENTS.md` provides the top-level task namespace summary.
