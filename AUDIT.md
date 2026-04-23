# nixconfig Audit: AI Modules & Closure Shrinking

## Executive Summary

The AI module surface is larger than the active footprint. Many modules are
imported conditionally but never enabled. The manifest system and its scripts
are dead code. Several flake inputs pull dependencies that nothing consumes.

---

## 1. Host-by-Host AI Service Matrix

| Service           | thinsandy | mtfuji | kellerbench | poseidon | garnixMachine |
|-------------------|-----------|--------|-------------|----------|---------------|
| nullclaw          | yes       | yes    | no          | yes      | yes           |
| nullclaw-deploy   | no        | yes    | no          | yes      | yes           |
| hermes-agent      | yes       | no     | no          | no       | no            |
| ollama            | yes       | yes    | yes         | no       | no            |
| xs                | yes       | no     | no          | no       | no            |
| pancakes-harness  | yes       | no     | no          | no       | no            |
| openclaw          | no*       | no*    | no          | no       | no            |
| openfang          | no*       | no*    | no          | no       | no            |

`*` imported but explicitly disabled (`enableOpenClaw = false`, `enableOpenFang = false`)

**Active hosts:** thinsandy is the only one running the full AI stack.
mtfuji runs nullclaw + ollama only. garnixMachine and poseidon run
nullclaw only. kellerbench runs ollama only (nullclaw disabled).

---

## 2. Safe to Remove (Unused Cruft)

### 2.1 Manifest system (user-confirmed dead)

| Path | Size | Rationale |
|------|------|-----------|
| `taskfiles/ai-host-manifest.json` | 2.9K | Never used per user |
| `scripts/task/ai-host-manifest.sh` | 6.9K | Manifest parser/CLI |
| `scripts/task/ai-host-drift-audit.sh` | 11.3K | Drift detection tied to manifest |
| `scripts/task/ai-host-evidence.sh` | 9.8K | Evidence collection tied to manifest |
| `scripts/task/ai-host-promote.sh` | 13.1K | Promotion logic tied to manifest |
| `scripts/task/ai-host-status.sh` | 18.5K | Status reporter tied to manifest |
| `flake/checks.nix` lines 90-93 | — | `ai-host-fleet-contract` check duplicates `host-architecture` check |
| `flake/checks.nix` lines 101-109 | — | `manifest-helper` check validates dead manifest |

**Action:** Delete the JSON, all five scripts, and the two checks.

### 2.2 User-level AI tools (mostly commented out)

| Path | Status |
|------|--------|
| `modules/user/ai/agents.nix` | Only referenced by disabled `opencode.nix` |
| `modules/user/ai/opencode.nix` | Commented out of `default.nix` ("too bloated") |
| `modules/user/ai/aichat.nix` | Imported but `aichat` package commented out |
| `modules/user/ai/mods.nix` | Imported but `mods` package commented out |
| `modules/user/ai/codex.nix` | Active in `default.nix`, but codex is also in systemPackages |
| `modules/user/ai/gemini-cli.nix` | Active, but gemini-cli is also in systemPackages |
| `modules/config/agents.json` | Orphaned agent template URL |

**Action:** The entire `modules/user/ai/` directory is dead weight for NixOS
hosts (system-level configs). The HM roles that might reference it are
`modules/roles/home.nix` (commented out) and `modules/roles/portable-home.nix`.
If no HM config actively imports `../user/ai`, delete the directory.

### 2.3 Unused flake inputs

| Input | Used? | Removal Impact |
|-------|-------|----------------|
| `pyproject-nix` | No references outside `flake.nix` | None |
| `uv2nix` | No references outside `flake.nix` | None |
| `pyproject-build-systems` | No references outside `flake.nix` | None |
| `nix-openclaw` | Only imported when `enableOpenClaw = true` (never) | Remove overlay imports + input |

**Action:** Remove four inputs from `flake.nix`. Run `nix flake update` to
shrink `flake.lock`.

### 2.4 Unused package definitions

| Package | Referenced? |
|---------|-------------|
| `pkgs/openfang.nix` | Service never enabled; package built but never deployed |
| `pkgs/qwen-code.nix` | Referenced in `thinsandy/tools.nix` — **KEEP** |
| `pkgs/xs-materializer.nix` | Referenced in `packages.nix` only, xs is thinsandy-only — **MAYBE KEEP** |

**Action:** `openfang` package can go if the service module also goes.

---

## 3. Modules to Refactor (Weak/Fragile)

### 3.1 `modules/services/ai-services-context.nix`

**Problems:**
- `isServiceEnabled` helper is a brittle string-conditional chain (lines 9-16)
- `serviceNames` default includes 6 services but only nullclaw/hermes are widely used
- Activation script copies files blindly without validation
- `contextFiles` default references `AGENTS.md` and `.agents` which may not exist

**Refactor:**
- Replace string conditionals with `lib.optionalAttrs` or direct option checks
- Filter `serviceNames` to only enabled services at the option level, not in a helper
- Add `test -d` guards before `cp -r`

### 3.2 `modules/services/ai-services-shared-mounts.nix`

**Problems:**
- `workspaceRoots` attrset hardcodes service names (nullclaw, openclaw, openfang)
- `skillsSource` logic for openfang is dead code (openfang never enabled)
- Complex `lib.optionalAttrs` chaining for mount units

**Refactor:**
- Generate `workspaceRoots` from `config.aiServices` directly
- Remove openclaw/openfang mount logic since services are never enabled
- Simplify to only handle nullclaw + hermes (the active set)

### 3.3 `modules/services/hermes-ai-mounts.nix`

**Problems:**
- Duplicates `ai-services-mounts.nix` logic for hermes specifically
- Exists because hermes-agent module doesn't expose mount options natively

**Refactor:**
- Merge into `ai-services-shared-mounts.nix` or upstream to hermes-agent module

### 3.4 `modules/profiles/ai-host.nix`

**Problems:**
- `withOpenclaw` parameter is always passed as `true` but then disabled via `enableOpenClaw = false`
- Assertion about nullclawDeployment coupling is overly strict

**Refactor:**
- Remove `withOpenclaw` parameter; import `openclaw-gateway.nix` unconditionally or drop it
- Simplify to just nullclaw enablement

---

## 4. Closure Shrinking Opportunities

### 4.1 Remove unused inputs (immediate)

```nix
# Remove from flake.nix inputs:
- pyproject-nix
- uv2nix
- pyproject-build-systems
- nix-openclaw
```

### 4.2 Remove unused overlays

```nix
# hosts/thinsandy/ai.nix and mtfuji/ai.nix:
# Delete the nix-openclaw overlay block (lines 31-35)
```

### 4.3 Remove dead imports from host configs

**thinsandy/ai.nix:**
- `openfang.nix` (service never enabled)
- `xs.nix` (actually enabled — keep)
- `pancakes-harness.nix` (actually enabled — keep)
- `nix-openclaw.nixosModules.openclaw-gateway` (never enabled)

**mtfuji/ai.nix:**
- `openfang.nix` (never enabled)
- `xs.nix` (enableXS = false)
- `pancakes-harness.nix` (enablePancakesHarness = false)
- `nix-openclaw.nixosModules.openclaw-gateway` (never enabled)
- `hermes-ai-mounts.nix` (enableHermes = false)

### 4.4 Simplify `ai-services-context.nix` defaults

Current default `serviceNames` includes 6 services. Reduce to active set:
```nix
serviceNames = ["nullclaw" "hermes"];
```
(xs and pancakes-harness are thinsandy-only; set explicitly there.)

---

## 5. Files to Touch (ordered by safety)

| Priority | File | Action |
|----------|------|--------|
| 1 | `taskfiles/ai-host-manifest.json` | Delete |
| 1 | `scripts/task/ai-host-*.sh` (×5) | Delete |
| 1 | `flake/checks.nix` | Remove `ai-host-fleet-contract` and `manifest-helper` checks |
| 2 | `flake.nix` | Remove 4 unused inputs |
| 2 | `modules/config/agents.json` | Delete |
| 3 | `modules/user/ai/` | Delete if no HM config imports it |
| 3 | `pkgs/openfang.nix` | Delete if service module deleted |
| 3 | `modules/services/openfang.nix` | Delete (never enabled) |
| 4 | `modules/services/openclaw-gateway.nix` | Delete (never enabled) |
| 4 | `hosts/thinsandy/ai.nix` | Remove openfang/openclaw imports |
| 4 | `hosts/mtfuji/ai.nix` | Remove openfang/xs/pancakes/openclaw/hermes-mounts imports |
| 5 | `modules/services/ai-services-context.nix` | Refactor service filtering |
| 5 | `modules/services/ai-services-shared-mounts.nix` | Remove dead service mounts |
| 5 | `modules/profiles/ai-host.nix` | Simplify, remove withOpenclaw param |

---

## 6. Validation Steps

After each batch:
1. `nix flake check` — must pass
2. `nix build .#nixosConfigurations.garnixMachine.config.system.build.toplevel` — must evaluate
3. `nix build .#nixosConfigurations.thinsandy.config.system.build.toplevel` — must evaluate
4. `nix build .#nixosConfigurations.mtfuji.config.system.build.toplevel` — must evaluate

---

## 7. Risk Assessment

| Change | Risk | Mitigation |
|--------|------|------------|
| Delete manifest + scripts | None | Confirmed dead by user |
| Remove flake inputs | Low | `nix flake check` catches missing inputs |
| Delete `modules/user/ai/` | Low | Verify no HM import in `roles/home.nix` |
| Delete openfang/openclaw modules | Low | Services never enabled on any host |
| Refactor ai-services-context | Medium | Only touches activation script; test on thinsandy |
| Simplify ai-host.nix | Medium | Used by 5 hosts; check all evaluate |
