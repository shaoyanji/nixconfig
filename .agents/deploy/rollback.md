# Rollback Routing

## Scope
How rollback is executed and validated for host operations.

## Source Of Truth
- Core rollback tasks: `taskfiles/services-core.yml`
- AI host evidence tasks: `taskfiles/services-ai-hosts.yml`
- AI host metadata: `taskfiles/ai-host-manifest.json`

## Canonical Task Surface
- Apply rollback: `services:rollback:apply:host:*`
- Rollback with post-validation evidence: `services:rollback:host:*`
- Post-rollback evidence capture: `services:evidence:rollback:host:*`

## Operational Notes
- Rollback mechanism currently uses remote `nixos-rebuild switch --rollback` via SSH.
- Post-rollback validation uses the same manifest-linked validation task resolution as normal validate flow.

## What Not To Assume
- Do not invent alternate rollback procedures in docs.
- Do not treat evidence scripts as direct entrypoints when task wrappers exist.
