# Handoff: Nixconfig Systematic Refactoring

**Date:** 2026-04-18
**Branch:** main (at `ff3d252`)
**Scope:** Deduplicate and modularize the nixconfig flake

## Context

We just migrated `mtfuji`, `thinsandy`, and `kellerbench` from the local
`hermes-agent-local.nix` wrapper to the upstream `services.hermes-agent`
module directly. This exposed a broader problem: the AI host configs are
copy-paste heavy with no shared abstraction layer.

## Current State

```
hosts/
  mtfuji/ai.nix        (228 lines) — services + ai + ollama + sops + fs
  thinsandy/ai.nix     (221 lines) — nearly identical to mtfuji
  kellerbench/         (125 lines) — same pattern, fewer services
modules/services/
  hermes-agent-local.nix (59 lines) — DEAD CODE, no longer imported
  ai-services-context.nix
  nullclaw-deployment.nix
  openclaw-gateway.nix
  openfang.nix
  xs.nix
  pancakes-harness.nix
flake/
  checks.nix — has thinsandy-specific hermes assertions
```

## Identified Duplication

### 1. systemd overrides — identical across ALL 3 hosts

Every host repeats this verbatim:

```nix
systemd.services.hermes-agent.serviceConfig = {
  BindReadOnlyPaths = [
    "/srv/data/ai-services/context:/var/lib/hermes/.ai-services/context"
    "-/srv/data/ai-services/defaults/shared.env:/var/lib/hermes/.ai-services/defaults/shared.env"
  ];
  BindPaths = [
    "/srv/data/ai-services/state/hermes:/var/lib/hermes/.ai-services/state"
  ];
  EnvironmentFile =
    [ "-/srv/data/ai-services/defaults/shared.env" ]
    ++ config.services.hermes-agent.environmentFiles;
};
```

→ Should be a shared module (e.g. `modules/services/hermes-ai-mounts.nix`)
   or folded into a host profile like `profiles/ai-host.nix`.

### 2. Hermes config — mtfuji and thinsandy are identical

```nix
services.hermes-agent = {
  settings = {
    model = { provider = "nous"; default = "xiaomi/mimo-v2-pro"; };
    terminal = { backend = "local"; timeout = 180; };
    toolsets = ["all"];
    memory.provider = "holographic";
  };
  environmentFiles = [ ... shared env ... ];
};
```

Kellerbench differs (openrouter model, no memory provider).

→ Extract to a shared hermes profile module with per-host overrides.

### 3. ai.nix mega-files — mtfuji and thinsandy are near-identical

Both contain full definitions for:
- nullclaw (deployment config)
- openfang (with shared context/state mounts)
- xs (with shared context/state mounts)
- pancakes-harness (with shared context/state mounts)
- sops.secrets (nullclaw, hermes, ai-services-shared-env)
- fileSystems (bind mounts for workspace sharing)
- ollama (with cloud models)
- services.ollama.loadModels

Only differences:
- thinsandy has openclaw gateway config (mtfuji doesn't)
- enable/disable flags differ per host
- thinsandy has more fileSystems bind mounts

→ These should be composable service modules, not monolithic ai.nix files.

### 4. Shared context/state mount pattern

Every AI service repeats this pattern:

```nix
contextRoot = "/srv/data/ai-services/context";
sharedDefaultsFile = "/srv/data/ai-services/defaults/shared.env";
sharedSecretFile = config.sops.secrets."ai-services-shared-env".path or null;
stateDir = "/srv/data/ai-services/state/<service>";
```

→ Already partially handled by `ai-services-context.nix` but still
   copy-pasted in each service definition.

### 5. Dead code

`modules/services/hermes-agent-local.nix` — 59 lines, zero imports.
`flake/checks.nix` has thinsandy-specific hermes assertions that may need
updating after the migration.

## Refactoring Plan

### Phase 1: Clean up dead code

- [ ] Delete `modules/services/hermes-agent-local.nix`
- [ ] Verify `flake/checks.nix` assertions still pass (update if needed)
- [ ] Run `nix eval` for all hosts to confirm no regressions

### Phase 2: Extract hermes shared config

- [ ] Create `modules/services/hermes-ai-mounts.nix`:
  - The systemd BindPaths/BindReadOnlyPaths/EnvironmentFile override
  - Enabled via an option like `services.hermes-agent.aiMounts.enable`
  - Or simpler: a profile in `modules/profiles/hermes-ai-host.nix`
- [ ] Create `modules/profiles/hermes-defaults.nix`:
  - Shared settings (model, terminal, toolsets, memory)
  - Shared environmentFiles pattern
  - Per-host overrides via `mkOverride` or `mkDefault`
- [ ] Remove duplicated systemd overrides from all 3 hosts
- [ ] Remove duplicated settings from all 3 hosts

### Phase 3: Modularize ai.nix mega-files

- [ ] Move per-service configs into their own module options:
  - nullclaw deployment → already in `nullclaw-deployment.nix` ✓
  - openfang config → already in `openfang.nix` ✓
  - xs config → already in `xs.nix` ✓
  - pancakes-harness → already in `pancakes-harness.nix` ✓
- [ ] Host files should only contain enable flags + host-specific overrides
- [ ] Extract sops.secrets to a shared secrets module
- [ ] Extract fileSystems bind mounts to a shared mounts module
- [ ] The goal: `hosts/mtfuji/ai.nix` shrinks from 228 → ~30 lines

### Phase 4: Audit and deduplicate other hosts

- [ ] Check other hosts (poseidon, aceofspades, etc.) for similar patterns
- [ ] `modules/profiles/ai-host.nix` — audit what it provides vs what's
  duplicated in host ai.nix files

### Phase 5: Validate

- [ ] `nix eval` for all 3 AI hosts (mtfuji, thinsandy, kellerbench)
- [ ] `nix eval` for any other hosts that might be affected
- [ ] Verify `flake/checks.nix` passes
- [ ] Deploy to one host first, verify service starts

## Key Decisions Needed

1. **Mount pattern**: Should BindPaths be an option on `services.hermes-agent`
   (upstream contribution?) or a local profile module?
2. **Shared hermes settings**: `mkDefault` per-host overrides vs.
   dedicated profile module with explicit option merging.
3. **ai.nix split**: Keep one `ai.nix` per host (slim) vs. move everything
   to modules and have hosts just set enable flags.
4. **Dead modules**: Delete `hermes-agent-local.nix` now or keep as
   reference until refactoring is complete?

## File Inventory

Total: ~9,100 lines across ~130 .nix files.

Files to modify:
- `hosts/mtfuji/ai.nix` — slim down
- `hosts/thinsandy/ai.nix` — slim down
- `hosts/kellerbench/configuration.nix` — slim down
- `flake/checks.nix` — update hermes assertions

Files to create:
- `modules/services/hermes-ai-mounts.nix` or `modules/profiles/hermes-ai.nix`

Files to delete:
- `modules/services/hermes-agent-local.nix`
