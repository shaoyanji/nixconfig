# nixconfig Audit: AI Modules & Closure Shrinking (Completed)

## Executive Summary

The AI module surface has been successfully simplified. Unused modules, manifest systems, and dead code have been removed. The task control plane has been consolidated and deprecated aliases removed.

---

## Completed Cleanup Actions (April 23, 2026)

### 1. Manifest System Removal
**Status:** ✅ Completed

Removed files:
- `taskfiles/ai-host-manifest.json`
- `scripts/task/ai-host-manifest.sh`
- `scripts/task/ai-host-drift-audit.sh`
- `scripts/task/ai-host-evidence.sh`
- `scripts/task/ai-host-promote.sh`
- `scripts/task/ai-host-status.sh`
- Related checks from `flake/checks.nix`

### 2. User-level AI Tools Cleanup
**Status:** ✅ Completed

Removed directories:
- `modules/user/ai/` (dead code for NixOS hosts)
- `modules/goodies.nix` (nothing in active host configs imported it)

### 3. Unused Flake Inputs
**Status:** ✅ Completed

Removed inputs from `flake.nix`:
- `pyproject-nix`
- `uv2nix`
- `pyproject-build-systems`
- `nix-openclaw`

### 4. Unused Package Definitions
**Status:** ✅ Completed

- `pkgs/openfang.nix` removed (service never enabled)
- `pkgs/xs-materializer.nix` retained (referenced in packages.nix)
- `pkgs/qwen-code.nix` retained (referenced in thinsandy/tools.nix)

---

## Additional Cleanup (April 30, 2026)

### Task System Consolidation
**Status:** ✅ Completed

- Deprecated legacy task aliases and menus in `taskfiles/services-legacy.yml`
- Consolidated git workflows in `taskfiles/dev.yml` with AI commit integration
- Simplified `checks:nullclaw:smoke` tasks
- Enhanced `dev:git` tasks with stash handling
- Added `dev:flake:update-complete` for comprehensive flake update workflow
- Added `scripts/task/nix-hash-update.sh` for managing Nix hashes

---

## Current AI Services State

### Active Host Matrix

| Host      | nullclaw | hermes-agent | ollama | xs | pancakes-harness |
|-----------|----------|--------------|--------|-----|------------------|
| thinsandy  | yes      | yes          | yes    | yes | yes              |
| mtfuji     | yes      | no           | yes    | no  | no               |
| garnixMachine | yes   | no           | no     | no  | no               |
| kellerbench | no      | no           | yes    | no  | no               |

### Current Module Structure

**Shared AI Service Modules:**
- `modules/services/nullclaw-deployment.nix` - Deployment wrapper
- `modules/services/nullclaw.nix` - Base service
- `modules/services/hermes-ai-mounts.nix` - Hermes mount configuration
- `modules/services/ai-services-secrets.nix` - Shared secrets
- `modules/services/ai-services-shared-mounts.nix` - Workspace mounts
- `modules/services/ai-services-context.nix` - Context file management
- `modules/services/xs.nix` - XS event streaming
- `modules/services/pancakes-harness.nix` - Pancakes harness service

**Profiles:**
- `modules/profiles/ai-host.nix` - AI host profile
- `modules/profiles/hermes-defaults.nix` - Hermes default settings
- `modules/profiles/ollama-cloud-defaults.nix` - Ollama cloud model defaults

---

## Documentation Updates

**Status:** ✅ Completed (April 30, 2026)

Updated documentation to reflect current state:
- `AGENTS.md` - Updated task routing references
- `docs/task-control-plane.md` - Rewritten for simplified task structure
- `taskfiles/README.md` - Updated ownership map
- `README.md` - Removed outdated AI manifest/fleet references
- `docs/nullclaw-fleet-pattern.md` - Simplified to remove evidence/drift/promotion flows
- `TODO.md` - Updated current work section

---

## Current Architecture

### Task Control Plane
Simplified namespace structure:
- `infra:*` - Host lifecycle, secrets, SOPS operations
- `agents:*` - Operator helpers, xs wrappers, OAuth management
- `checks:*` - Validation and smoke checks
- `dev:*` - Git workflows, flake updates, site deployment
- `services:*` - Legacy compatibility wrappers (deprecated)

### Deployment Workflow
Standard deployment uses `infra:*` tasks:
```bash
task infra:plan:host:<host>     # Build/evaluate
task infra:apply:host:<host>    # Apply configuration
task checks:nullclaw:smoke:<host>  # Validate
```

Or combined:
```bash
task infra:deploy:host:<host>   # Plan + apply + validate
```

### Validation
Basic smoke checks via `task checks:nullclaw:smoke:<host>` verify:
- Service active status
- Workspace directory existence
- Listener binding
- Secret/config file readability
- Optional health endpoint

---

## Remaining Technical Debt

### Minor Refactoring Opportunities
1. **ai-services-context.nix**: Service filtering could be auto-derived from enabled services rather than manual listing
2. **ai-services-shared-mounts.nix**: Could simplify to only handle nullclaw + hermes (active set)
3. **ollama cloud models**: mtfuji/thinsandy share identical model lists - could extract to shared option

### Not Worth Refactoring
- Ollama service config (kellerbench uses cuda + no loadModels — too different)
- btrfs fileSystems (device UUIDs are host-specific)
- hermes secrets (host-specific: mtfuji skips it, thinsandy includes it)

---

## Risk Assessment

All cleanup actions completed successfully with:
- ✅ No breaking changes to active deployments
- ✅ All hosts still evaluate correctly
- ✅ Validation checks pass
- ✅ Documentation aligned with actual implementation

The codebase is now in a cleaner state with reduced complexity and better alignment between documentation and implementation.