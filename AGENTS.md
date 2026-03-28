# AGENTS.md

## Repo Identity
This repository is a Nix flake for host configurations, service profiles, and operator workflows.

## Routing Boundaries
- `Taskfile.yml` and `taskfiles/*` are the executable control-plane truth.
- `scripts/task/*` are helper implementation details used by task entries.
- `taskfiles/ai-host-manifest.json` is operator metadata for AI hosts.
- `.agents/*` is guidance and routing only. It is not execution truth.

## Deploy Work Routing
- Start at `.agents/deploy/README.md` for deployment workflow routing.
- Use `.agents/deploy/ai-hosts.md` for AI host deploy/validate/promote/drift/evidence flows.
- Use `.agents/deploy/rollback.md` for rollback flow references.
- Use `.agents/deploy/promotion.md` for promotion/readiness flow references.
- Use `.agents/deploy/website.md` for website/static sync scope.
- Use `.agents/deploy/hosts/*.md` only for host-specific operational exceptions.

## Canonical File Surfaces
- Task entrypoints: `Taskfile.yml`, `taskfiles/services-core.yml`, `taskfiles/services-ai-hosts.yml`, `taskfiles/services-legacy.yml`, `taskfiles/checks.yml`, `taskfiles/dev.yml`
- AI host metadata: `taskfiles/ai-host-manifest.json`
- Host declarations for flake outputs: `flake/host-inventory.nix`
- Role/module canonical paths: `modules/roles/*`, `modules/user/*`, `modules/shell/*`

## Operational Guardrails
- Preserve runtime behavior unless explicitly changing behavior.
- Prefer small, reviewable diffs.
- Do not edit secrets or encrypted payloads.
- Do not move executable logic into `.agents/*`.
- Do not treat `.agents/*` as a second source of truth.
