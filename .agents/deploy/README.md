# Deploy Routing

## Scope
Operator deploy activity means `infra:*` for host lifecycle flows.

## Entry points
- `taskfiles/infra.yml` (`infra:*`) runs rebuilds, switches, boots, deploys, and logs.

## Host cards
A card exists only where a host departs from the chain, and each one is listed
here so no card is an orphan:

- [`hosts/delphi.md`](hosts/delphi.md) — OCI Ampere A1 provisioning, the `sandbox`
  microVM guest, and how the deck is reached (`ssh slides@delphi.bountystash.com`).
- [`hosts/eisen.md`](hosts/eisen.md) — LLM stack operations; architecture and
  measurements are [`docs/eisen-llm-architecture.md`](../../docs/eisen-llm-architecture.md).
- [`hosts/frieren.md`](hosts/frieren.md) — NAS self-upgrade topology and its traps.
- [`hosts/netbook.md`](hosts/netbook.md) — pinned boot chain, push deploy, and the
  two on-target guards (kernel/initrd, `/etc/nixos` drift).
- [`hosts/scratch.md`](hosts/scratch.md) — throwaway host conventions.
- [`hosts/stark.md`](hosts/stark.md) — All-in-One Steam kiosk, first-boot disk layout.

A decommissioned host needs no card: its facts belong in `inventory.toml`
(mtfuji's moved there on 2026-10-21, and the card was deleted).

## Determinate Nix (fleet-wide since 2026-10-19)
Every NixOS host runs Determinate Nix via `modules/global/determinate-nix.nix`.
Two things change for a deploy:

- **Bootstrap.** A switch that *adds* DN must pass its cache on the command line,
  because the module's `substituters` entry only exists after activation:
  `--option substituters https://install.determinate.systems --option trusted-public-keys cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM=`
  (or pre-fetch the closure with `nix copy --from https://install.determinate.systems`).
  Without it the switch compiles 54 derivations instead of fetching them.
- **Rollback.** `nixos-rebuild --rollback switch`, or boot the previous generation.
  The store format is unchanged, so there is no migration in either direction.

Filtering lies with DN: `determinate-nixd` owns `/etc/nix/nix.conf`, and the fleet's
`nix.settings` live in the included `nix.custom.conf` — check that file, not `nix.conf`.

## Guardrails
- `.agents/*` documents routing only; Taskfiles are the executable truth.
- Avoid duplicating the manifest.
