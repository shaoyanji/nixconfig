# nixconfig Audit: AI Modules & Closure Shrinking (Completed)

## Executive Summary

The AI module surface has been successfully simplified. Unused modules, manifest systems, and dead code have been removed. The task control plane has been consolidated and deprecated aliases removed.

**September 2026 update:** the remaining agent-era tooling was removed entirely (see below). Sections describing the "Current AI Services State" and "Current Architecture" as of April 2026 are historical; the state at the end of this document reflects September 2026.

**October 2026 update:** host services were modularized into `modules/services/` (Home Assistant stack, declarative Kiwix wiki, fleet pastebin `pb`, and iVentoy PXE server). The pending SOPS drift debt was completely resolved, `deadnix` and `statix` lints were resolved, 100% Alejandra style compliance was achieved (0/181 files failing), and corresponding agent skills were authored and indexed in `.agents/skills/`.

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

### SOPS re-key (thinsandy anchor removal)
**Status:** ✅ Completed (`eacbad6`, verified 2026-10-08)

All 6 SOPS files (`apikeys.yaml`, `DE-Taskfile.yaml`, `fullsecrets.yaml`, `secrets.yaml`, `modules/secrets.yaml`, `modules/ssh-ca-key.yaml`) have been re-keyed against `.sops.yaml`. Decommissioned thinsandy keys are cleanly purged; `task checks:sops:drift` passes 100% across all files.

---

## Session: October 8, 2026 — Service Modularization, Hardware Alignment & Clean Lint Convergence

### 1. Reusable Service Modularization
**Status:** ✅ Completed (`e954e9a`)

Refactored four host-coupled services out of `hosts/frieren/` and into first-class reusable modules under `modules/services/` conforming to `AGENTS.md` ("reuse modules rather than per-host copies"):
- **Home Assistant IoT Stack (`modules/services/home-assistant.nix`):** Extracted Home Assistant from `hosts/frieren/media-stack.nix` and combined it with Mosquitto (`127.0.0.1:1883`) and Uptime-Kuma (`:3001`) under the new `services.ha-stack` option. Media daemons (Jellyfin, Plex, Immich, *arr, Anki) remain isolated in `media-stack.nix`.
- **Offline Wiki Stack (`modules/services/kiwix.nix`):** Declarative Wikipedia (19.2M articles) + ArchWiki (14.5k articles) served on `:8088` and `http://wiki.frieren.lan/`.
- **Fleet Pastebin (`modules/services/paste.nix`):** Private fleet paste utility (`pb`) serving on `http://paste.frieren.lan/` with 30-day tmpfiles auto-expiry.
- **Network PXE Boot (`modules/services/iventoy.nix`):** Bare-metal provisioning and ISO streaming server for `/Volumes/data/isos`.

### 2. Lint-Gate & Formatting Sweep
**Status:** ✅ Completed
- Resolved `deadnix` unused declarations in `modules/services/home-assistant.nix` (`pkgs,`) and `modules/user/ai/hermes-user.nix` (`personaDir`).
- Applied `statix` suggestion (`inherit (cfg) openFirewall`).
- Ran full Alejandra formatting sweep: 181/181 files compliant (0 formatting violations). `task checks:nix:lint` and `task checks:quick` both exit 0.

### 3. Agent Skills Materialization & Guidance
**Status:** ✅ Completed (`841643f`)
- Authored operational skills with runbooks:
  - `.agents/skills/home-assistant/SKILL.md` (Home Assistant, Mosquitto MQTT, host telemetry, Uptime-Kuma)
  - `.agents/skills/paste/SKILL.md` (Fleet pastebin CLI `pb`, lifecycle, remote usage)
  - `.agents/skills/iventoy/SKILL.md` (PXE boot server, ISO library, client boot steps)
  - `.agents/skills/wikisearch/SKILL.md` (Offline Kiwix BM25 search)
  - `.agents/skills/stt/SKILL.md` (Voxtype speech-to-text daemon)
- Registered all skills in `.agents/README.md` and synced into user home `~/.agents/skills/`.

### 4. DNS Routing Domain Hardening
**Status:** ✅ Completed (`eacbad6`)
- Configured `Domains = ["~frieren.lan"]` in `hosts/frieren/dns.nix` under `services.resolved.settings.Resolve`, ensuring resolved always routes `.frieren.lan` queries to the local Pi-hole/Unbound stack rather than deferring to router DHCP on wireless interfaces.

### 5. Storage Reclamation
**Status:** ✅ Completed
- Reclaimed 52 GB duplicate Wikipedia ZIM from `/var/lib/kiwix/` after hash verification (`441a56d9...`). Single source of truth retained as GC-rooted Nix store path (`/nix/var/nix/gcroots/per-user/devji/wikipedia-zim`).

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
- ~~sops re-key of `modules/secrets.yaml` + `modules/ssh-ca-key.yaml`~~ — ✅ Resolved (October 2026, 100% drift-free across all 6 SOPS files).

### Active Fleet Recommendations (Forward Roadmap)
1. **Periodic Fleet Warm Cache:** Observe the weekly `fleet-warm-cache` timer (Sundays 01:30) and monitor disk pressure on frieren (`/nix/store` and `/srv/data`).
2. **Dual-Target Restic Backup:** Evaluate adding a secondary offsite restic repo (Backblaze B2 or remote rest-server) alongside the local `/srv/backup/restic` target.
3. **Monitor nixbuild.net Usage:** Track remote builder usage against the 25 build-hours/month limit (`task dev:nixbuild:plan`).
4. **LAN Mosquitto Listener Authentication:** When physical ESP32 or Zigbee sensor nodes are deployed, configure authenticated TLS/TCP listeners on Mosquitto (`services.mosquitto.listeners`).

### Not Worth Refactoring
- Ollama service config (kellerbench uses cuda + no loadModels — too different)
- btrfs fileSystems (device UUIDs are host-specific)

---

## Risk Assessment

(As of October 2026 — all 20 NixOS hosts, cassini, and penguin evaluate cleanly, `task checks:quick` and `task checks:nix:lint` exit 0, formatter convergence at 100% Alejandra compliance with 0 violations across 181 tracked Nix files, and SOPS secrets are 100% drift-free.)

All cleanup actions completed successfully with:
- ✅ No breaking changes to active deployments
- ✅ All hosts still evaluate correctly
- ✅ Validation checks pass
- ✅ Documentation aligned with actual implementation

The codebase is now in a clean, reproducible, and robust state.