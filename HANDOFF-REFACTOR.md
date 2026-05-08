# Handoff: Nixconfig Systematic Refactoring

**Date:** 2026-04-18 (updated after rounds 1-2)
**Branch:** main (at `c16eeee`)
**Scope:** Deduplicate and modularize the nixconfig flake

## Context

We migrated `mtfuji`, `thinsandy`, and `kellerbench` from the local
`hermes-agent-local.nix` wrapper to the upstream `services.hermes-agent`
module directly. This exposed a broader problem: the AI host configs are
copy-paste heavy with no shared abstraction layer.

## Progress

### Round 1 — Hermes mount extraction (committed `8d67306`)

- Deleted `modules/services/hermes-agent-local.nix` (dead code)
- Created `modules/services/hermes-ai-mounts.nix` — `aiServices.hermesMounts.enable`
- Added `mkHermesMountConfig` to `ai-services-mounts.nix` helper
- Replaced hand-written systemd overrides in all 3 hosts

### Round 2 — Shared secrets, mounts, hermes defaults (committed `c16eeee`)

- Added `sops.secrets.nullclaw` to `nullclaw.nix` (removed from all 3 hosts)
- Created `modules/services/ai-services-secrets.nix` — `aiServices.sharedSecrets.enable`
- Created `modules/services/ai-services-shared-mounts.nix` — workspace-share bind mounts
- Created `modules/profiles/hermes-defaults.nix` — shared settings as mkDefault
- Removed duplicated sops.secrets, heres settings, and bind mounts from hosts

### Current host sizes

```
hosts/
  mtfuji/ai.nix               151 lines (was 228, -34%)
  thinsandy/ai.nix             148 lines (was 221, -33%)
  kellerbench/configuration.nix 101 lines (was 125, -19%)
```

## Remaining duplication (next session)

### 1. Shared mount options repeated per-service per-host (highest impact)

Every service config (xs, pancakesHarness) repeats this block:

```nix
contextRoot = "/srv/data/ai-services/context";
sharedDefaultsFile = "/srv/data/ai-services/defaults/shared.env";
sharedSecretFile = config.sops.secrets."ai-services-shared-env".path or null;
stateDir = "/srv/data/ai-services/state/<service>";
```

These are identical across ALL hosts. The fix: set them as `mkDefault` in each
service module's config. Hosts only override if they differ (none currently do).

Per service module (xs.nix, pancakes-harness.nix):
```nix
config = lib.mkIf cfg.enable {
  aiServices.xs = {
    contextRoot = lib.mkDefault "/srv/data/ai-services/context";
    sharedDefaultsFile = lib.mkDefault "/srv/data/ai-services/defaults/shared.env";
    sharedSecretFile = lib.mkDefault (config.sops.secrets."ai-services-shared-env".path or null);
    stateDir = lib.mkDefault "/srv/data/ai-services/state/xs";
  };
  # ... existing config ...
};
```

Would cut ~12 lines per service per host. After this, xs/pancakesHarness
blocks in host files shrink to just `enable` + host-specific values (package, etc).

### 2. Ollama cloud models identical on mtfuji/thinsandy

Same 6-model loadModels list. Extract to a shared option or ai-host profile
(`profiles.aiHost.ollama.cloudModels.enable`).

### 3. ai-services-context serviceNames could be auto-derived

Each host manually lists `serviceNames`. The module already checks which services
are enabled — it could derive the list from `config.services.hermes-agent.enable`,
`config.aiServices.nullclaw.enable`, etc. instead of requiring a manual list.

## Not worth extracting

- Ollama service config (kellerbench uses cuda + no loadModels — too different)
- btrfs fileSystems (device UUIDs are host-specific)
- hermes secrets (host-specific: mtfuji skips it, thinsandy/kellerbench include it)

## Target state

mtfuji/thinsandy ai.nix at ~80-90 lines: just enable flags, host-specific
overrides (package, ollama, btrfs), and the service modules provide all
standard paths as defaults.

## Validation

- `flake/checks.nix` assertions still pass (verified: checks reference
  `services.hermes-agent.environmentFiles` which is unchanged)
- Need `nix eval` for all 3 AI hosts to confirm after each round
