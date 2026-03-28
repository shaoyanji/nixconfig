# Deploy Routing

## Scope
This directory routes deployment/operator work to the executable surfaces already present in the repo.

## Source Of Truth
- Execution: `Taskfile.yml` and `taskfiles/*`
- Script implementation: `scripts/task/*`
- AI host metadata: `taskfiles/ai-host-manifest.json`
- This directory: guidance only

## Deploy Terms In This Repo
- Deploy: build/evaluate + remote apply (and optionally validate)
- Validate: run host validation task when defined by manifest
- Promote: evidence + drift + readiness/receipt flow for AI hosts
- Rollback: remote rollback plus post-rollback validation/evidence

## Canonical Task Surfaces
- Core deploy/apply/validate/rollback/log flows: `taskfiles/services-core.yml`
- AI host evidence/drift/status/promotion flows: `taskfiles/services-ai-hosts.yml`
- Legacy aliases/menus: `taskfiles/services-legacy.yml`
- Validation checks: `taskfiles/checks.yml`

## AI Host Work
Use `.agents/deploy/ai-hosts.md` first, then follow task and manifest references there.

## Website/Non-AI Surface
See `.agents/deploy/website.md` for the current website/static sync path.

## Host Exceptions
Use `.agents/deploy/hosts/*.md` only when host-specific behavior differs operationally.
Do not copy full host definitions into these files.

## What Not To Assume
- Do not assume `.agents/*` can replace task definitions.
- Do not assume host metadata exists outside `taskfiles/ai-host-manifest.json` for AI host operator facts.
