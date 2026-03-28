# Agent Guidance Index

- **Tasks**: `Taskfile.yml` loads the `taskfiles/*` shards. Use `task --list-all` or `task help` to see namespaced entrypoints; `docs/task-control-plane.md` explains the namespace policy.
- **AI host metadata**: `taskfiles/ai-host-manifest.json` is the single manifest. Query it via `scripts/task/ai-host-manifest.sh` or the `agents:hosts:*` wrappers in `taskfiles/agents.yml`.
- **Host lifecycle tasks**: Canonical operations live under `infra:*` (`taskfiles/infra.yml`). The legacy `services:*` names now wrap back into `infra:*` via `taskfiles/services-core.yml`.
- **AI validation/evidence/promotion flows**: Those stay under `services:*` (`services:validate:host:*`, `services:evidence:*`, `services:promote:*`) and are detailed in `.agents/deploy/ai-hosts.md`.
- **Deploy guidance**: `.agents/deploy/README.md` is the starting point; the nested readmes (`ai-hosts.md`, `rollback.md`, `promotion.md`, `website.md`) and the host-specific `.agents/deploy/hosts/*.md` files cover exceptions.
