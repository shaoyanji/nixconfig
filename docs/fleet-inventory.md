# Fleet Device & Host Inventory

> **Moved — this page is generated now.**
>
> The fleet catalog, hardware profiles, per-host pages and the agent persona
> tables are built from `inventory.toml` by `lib/docs.nix`:
>
> - source of truth: `inventory.toml` (compiled once by `lib/inventory.nix`)
> - build: `nix build .#docs` → `<store>/docs/generated/fleet-inventory.md`
> - read it: `task docs:build` prints the store path; `.#sites.fleet-docs-site`
>   serves the same pages as HTML
> - per-host pages: `<store>/docs/generated/hosts/`
>
> Nothing is checked in — the tree is a store path, so there is no copy to
> refresh and no drift gate to run. This file is kept as a stable path for old
> links; editing it does nothing — change `inventory.toml` (or `lib/docs.nix`).
