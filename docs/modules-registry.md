# Fleet Modular Control Knob Registry

> **Moved — this page is generated now.**
>
> The knob registry is built from `modules.toml` by `lib/docs.nix`, alongside the
> fleet inventory and per-host pages, so it cannot lag the registry:
>
> - source of truth: `modules.toml`
> - build: `nix build .#artifacts.docs` → `<store>/docs/generated/modules-registry.md`
> - read it: `task docs:build` prints the store path
> - interactive manager: `task modules` (`task dev:modules:menu`)
>
> Nothing is checked in, so there is nothing to refresh. `task dev:modules:sync`
> still works — it builds the registry (`task docs:build`).
