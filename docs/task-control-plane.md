# Task Control Plane

This repository uses a simplified task namespace for predictable operator workflows.

## Current Namespace Structure

- `infra:*`: Host lifecycle operations (plan/apply/deploy/rollback/logs), secrets management, SOPS operations
- `agents:*`: Operator helpers, xs runtime wrappers, OAuth/session management for service users
- `checks:*`: Validation and smoke checks (primarily nullclaw deployment validation)
- `dev:*`: Git workflows, flake updates, site deployment, and local development tasks
- `services:*`: Legacy compatibility wrappers (routes to `infra:*` tasks)

## Taskfile Organization

- `Taskfile.yml`: Main entrypoint with top-level menus (deploy, logs, status, menu)
- `taskfiles/infra.yml`: Host lifecycle, secrets, SOPS operations
- `taskfiles/agents.yml`: Operator helpers, xs wrappers, OAuth management
- `taskfiles/checks.yml`: Validation and smoke checks
- `taskfiles/dev.yml`: Git workflows, flake updates, site deployment
- `taskfiles/services-core.yml`: Minimal compatibility wrappers
- `taskfiles/services-legacy.yml`: Deprecated aliases (marked `[deprecated]`)

## Common Workflows

### Host Deployment
```bash
task infra:deploy:host:<host>    # Plan + apply + validate
task infra:plan:host:<host>      # Build/evaluate only
task infra:apply:host:<host>     # Apply configuration only
```

### Local Rebuilds
```bash
task infra:rebuild:nixos         # Rebuild local NixOS host
task infra:rebuild:darwin        # Rebuild local Darwin host
task infra:rebuild:home-manager  # Rebuild Home Manager profile
```

### Git & Flakes
```bash
task dev:git:quick-push          # Commit/push with AI-generated message
task dev:flake:update-complete   # Complete flake update workflow
task dev:flake:update:bountystash # Update single flake input
```

### Validation
```bash
task checks:quick                # Run narrow repo checks
task checks:nullclaw:smoke:<host> # Smoke-check nullclaw deployment
```

### Operator Helpers
```bash
task agents:menu                 # Interactive operator menu
task agents:xs:status            # Show xs-helper status
task agents:oauth:list           # List known OAuth services
```

## Legacy Migration

Many tasks in `services-legacy.yml` are marked `[deprecated]` and route to canonical `infra:*` or `dev:*` tasks. Prefer using the canonical namespaces directly for new workflows.
