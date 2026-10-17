# Fleet Modular Control Knob Registry

> **Moved — this page is generated now.**
>
> The knob registry is built from `modules.toml` by `lib/docs.nix`, alongside the
> fleet inventory and per-host pages, so it cannot lag the registry:
>
> - source of truth: `modules.toml`
> - build: `nix build .#docs` → `docs/generated/modules-registry.md`
> - checked-in copy: [`generated/modules-registry.md`](generated/modules-registry.md)
> - interactive manager: `task modules` (`task dev:modules:menu`)
> - refresh: `task docs:sync` · verify: `task checks:docs:sync`
>
> `task dev:modules:sync` still works — it delegates to `task docs:sync`.
