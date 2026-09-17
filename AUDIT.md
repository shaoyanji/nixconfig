# nixconfig Audit: AI Modules & Closure Shrinking (Completed)

## Executive Summary

The AI module surface has been successfully simplified. Unused modules, manifest systems, and dead code have been removed. The task control plane has been consolidated and deprecated aliases removed.

**September 2026 update:** the remaining agent-era tooling was removed entirely (see below). Sections describing the "Current AI Services State" and "Current Architecture" as of April 2026 are historical; the state at the end of this document reflects September 2026.

---

## Session: September 17, 2026 — Agent-era teardown & lint-gate hardening

### Agent-era tooling removal
**Status:** ✅ Completed (`6c178a3`)

Decision: after the earlier scale-back, **no machine runs agents anymore**. mtfuji is kept as a registered reference host (data on disk, ollama active); everything else goes. The xs stack was classified the same way by the operator ("low use but fun to implement — clean deletion is fine"). Git history retains it all.

Removed modules: `profiles/{ai-host,hermes-defaults,ollama-cloud-defaults}.nix`, `services/{nullclaw,nullclaw-deployment,zeroclaw,zeroclaw-deployment,pancakes-harness,hermes-ai-mounts,ai-services-secrets,ai-services-shared-mounts,ai-services-context,xs}.nix`, `lib/ai-services-mounts.nix`, `services/shared.env.example`.

Removed packages: `pkgs/{nullclaw,pancakes-harness,qwen-code,xs,xs-helper,xs-materializer}.nix` — the `packages` flake output is now `{}` (output class kept for `nix flake check` completeness). Removed scripts: `scripts/task/{xs-helper.sh,xs-schema.py,service-oauth.sh}`. Removed docs: both fleet-pattern docs.

Host changes:
- `hosts/mtfuji/ai.nix` → plain module: ollama + the `nix/ollama`/`nix/nullclaw` btrfs subvols only (on-disk data preserved), decommission note at top
- poseidon: zeroclaw deployment block, aiHost profile, ai-services-secrets import, telegram sops secret/template all removed
- garnixMachine/kellerbench: dormant agent comment blocks purged (garnix bountystash wiring untouched)

Flake/taskfile changes: `nullclawFleetContract` check deleted (it asserted `deploymentEnabled = true` for hosts that had it commented out), `apps.xs-helper` removed (empty `apps` attrset kept), smoke checks deleted from `taskfiles/checks.yml`, `services:validate:host:*` now runs `systemctl is-system-running` over SSH, `agents:xs:*`/`agents:oauth:*` task blocks and their scripts removed.

Ride-along: tailscale DNS via pi-hole moved from the decommissioned thinsandy IP to frieren (`100.97.61.65`) in `modules/profiles/desktop-client.nix` and eisen.

### Check architecture: per-host evals
**Status:** ✅ Completed (`f0230e9`)

The monolithic `host-eval-all` check passed ~20 host toplevels as env attrs of a single `runCommand` and kept getting OOM-killed (this machine reproduced it 3×). Replaced with 22 per-host `host-eval-<host>` derivations: each forces exactly one host's module-system eval by interpolating the toplevel into the echoed message and strips the context (`unsafeDiscardStringContext`), so the derivation is a trivial echo and CI/garnix can parallelise. Rejected designs: `deepSeq toplevel` (blows eval call depth) and `test -e ${toplevel}` in the builder (string context would build the host closure).

### Pre-commit hook hardening
**Status:** ✅ Completed (`cecb93f`, `c97c904`)

- Hook accepts alejandra **or** nixpkgs-fmt per file; tool resolution: PATH → `nix build` from the `flake.lock`-pinned nixpkgs rev (machine-independent) → fail closed for formatters, skip-with-notice for deadnix/statix
- `statix check` runs per-file (pinned statix 0.5.8 accepts one target; the old multi-file invocation would have blocked any commit with 2+ staged files on machines where statix is installed)
- statix is advisory; deadnix + formatters are hard gates
- Formatter convergence: 75 files that matched *neither* formatter were run through alejandra 4.0.0 (`fabeb9d`), AST-verified against HEAD (ATerm comparison, same-dir to avoid path-literal pollution) — pure whitespace/comment churn except two intentional devShell fixes

### Lint-gate (CI) repair
**Status:** ✅ Completed (`8b12676`, `e1600e2`, `df4919b`)

CI's `checks:nix:lint` runs `deadnix --fail` over the whole tree; it was failing on pre-existing unused lambda args in 10+ files. All removed via `deadnix --edit`, reformatted, affected hosts re-evaluated. All eight `{...}:` empty patterns (statix W10) converted to `_:`. Final state: `task checks:nix:lint` exits 0; 0 of 179 tracked nix files fail both formatters.

### Pending: sops re-key (requires key holder)
**Status:** ⚠️ Open

`checks:sops:drift` fails on `modules/secrets.yaml` and `modules/ssh-ca-key.yaml`: they still embed the thinsandy age recipients removed from `.sops.yaml` in `f0230e9`. The April "no rekey needed" assessment was wrong — anchor removal must be followed by `sops updatekeys` from a machine holding an authorized age key (this Codespace has none by design). Until then, drift-check CI stays red; afterwards, the decommissioned thinsandy key genuinely loses read access (the security property the purge wanted).

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
- `pkgs/xs-materializer.nix` retained (referenced in packages.nix) — *removed 2026-09*
- `pkgs/qwen-code.nix` retained (referenced in thinsandy/tools.nix) — *removed 2026-09*

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

## Historical: AI Services State (April 2026 — superseded by the September 2026 teardown above)

> Everything listed here was removed in September 2026; thinsandy itself was decommissioned earlier that month.

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

## Historical: Architecture (April 2026 — superseded)

> Task namespace names survive, but the nullclaw smoke checks and xs/OAuth helpers shown below no longer exist.

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
1. ~~ai-services-context.nix service filtering~~ — obsolete (module removed 2026-09)
2. ~~ai-services-shared-mounts.nix simplification~~ — obsolete (module removed 2026-09)
3. ~~ollama cloud model list dedup~~ — obsolete (defaults module removed 2026-09; mtfuji keeps a plain `services.ollama.enable`)

### Open
- sops re-key of `modules/secrets.yaml` + `modules/ssh-ca-key.yaml` (see the September 2026 entry) — the only live debt item

### Not Worth Refactoring
- Ollama service config (kellerbench uses cuda + no loadModels — too different)
- btrfs fileSystems (device UUIDs are host-specific)

---

## Risk Assessment

(As of April 2026; re-validated for the September 2026 teardown — all 20 NixOS hosts, cassini, and penguin evaluate, `task checks:nix:lint` exits 0, formatter convergence at 0/179 files failing both formatters. One open item: the sops re-key above.)

All cleanup actions completed successfully with:
- ✅ No breaking changes to active deployments
- ✅ All hosts still evaluate correctly
- ✅ Validation checks pass
- ✅ Documentation aligned with actual implementation

The codebase is now in a cleaner state with reduced complexity and better alignment between documentation and implementation.