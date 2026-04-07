# Codex Handoff

## Purpose

This is the hands-on orientation for a Codex session. Architecture specifics live in `README.md` and `docs/task-control-plane.md`; this file keeps you focused on the behavior to preserve, the validation flow, and the near-term work.

## Behavior that must stay stable

- **thinsandy** – keep nullclaw/openclaw/hermes enabled, and preserve the current secret paths, workspace roots, and host-local bind mounts.
- **garnixMachine** – continue as the minimal nullclaw host on `127.0.0.1:3001` with configs staged from `/run/secrets/nullclaw-config`, nginx proxying to `http://127.0.0.1:3000/`, and no SOPS or persistence assumptions.
- **mtfuji** – retain the existing nullclaw env-file handling.
- **poseidon & ancientace** – keep only `hosts/<host>/configuration.nix`, their embedded `testvm` guests, and existing bridge/NAT wiring.

## Validation guidance

- All evaluations run against git-tracked files only.
- Narrow flows catch structural issues faster than broad `nix flake check` runs.

Recommended commands:

```bash
git status --short
nix eval .#nixosConfigurations.thinsandy.config.networking.hostName
nix eval .#nixosConfigurations.garnixMachine.config.networking.hostName
nix eval .#packages.x86_64-linux.nullclaw.meta.mainProgram
nix build .#checks.x86_64-linux.host-architecture -L
```

## Current known notes

- `garnixMachine` now evaluates to `networking.hostName = "garnixMachine"`; keep this stable unless an explicit host rename is intended.
- `hosts/common/disko.nix` remains an intentional host-local exception.

## Next recommended tasks

1. Keep reviewing `hosts/common/*` to verify only host-local behavior remains there.
2. Expand shared `testvm` usage only when a host genuinely benefits without disrupting host-local networking.
3. Keep the documentation set lean so each file owns a single responsibility.
