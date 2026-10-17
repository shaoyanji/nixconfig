# Fleet Device & Host Inventory

> **Moved — this page is generated now.**
>
> The fleet catalog, hardware profiles, per-host pages and the agent persona
> tables are built from `inventory.toml` by `lib/docs.nix`:
>
> - source of truth: `inventory.toml` (compiled once by `lib/inventory.nix`)
> - build: `nix build .#docs` → `docs/generated/fleet-inventory.md`
> - checked-in copy: [`generated/fleet-inventory.md`](generated/fleet-inventory.md)
> - per-host pages: [`generated/hosts/`](generated/hosts/)
> - refresh: `task docs:sync` · verify: `task checks:docs:sync`
>
> This file is kept as a stable path for old links. Editing it does nothing —
> change `inventory.toml` (or `lib/docs.nix`) instead.
