# mtfuji Exceptions

## Scope

mtfuji is a **decommissioned AI-host reference** (2026-09). The agent-era
tooling (nullclaw, hermes, xs, pancakes-harness) was removed from the repo;
the host keeps ollama and the btrfs data subvols for its on-disk state.

## Key Differences

- Runs `services.ollama` with dedicated btrfs subvols (`nix/ollama`, `nix/nullclaw`).
- No agent services; `hosts/mtfuji/ai.nix` is a minimal reference module now.

## Operational Interpretation

- Canonical host deploy flow (`infra:deploy:host:mtfuji`) works as usual.
- The old `checks:nullclaw:smoke:mtfuji` validation is gone along with the fleet tooling.
