# Nullclaw Fleet Pattern

## Scope
This pattern standardizes nullclaw deployment across hosts while keeping host-specific logic explicit.

Shared module:
- `modules/services/nullclaw-deployment.nix`

Current hosts using the pattern:
- `hosts/garnixMachine.nix`
- `hosts/mtfuji/configuration.nix`

## What the Shared Module Does
`aiServices.nullclawDeployment` wraps `aiServices.nullclaw` and provides:
- explicit host input surface for bind/port/workspace/env file
- optional staging of a runtime `config.json` into `workspaceRoot/.nullclaw`
- a single place for fleet-safe nullclaw host wiring

It does not manage:
- SOPS key material and encrypted payloads
- host networking/reverse-proxy policy
- host persistence/bind mounts

## Required Host Inputs
When `aiServices.nullclawDeployment.enable = true`, set:
- `listenHost`
- `listenPort`
- `workspaceRoot`

Optional:
- `environmentFile` (for env-based secrets)
- `configJsonSource` (source file staged before start)

## Add a New Machine
1. Import the module in the host file:
   - `../../modules/services/nullclaw-deployment.nix` (or equivalent relative path)
2. Enable profile/module as needed:
   - keep `profiles.aiHost.nullclaw.enable = true` if using the AI host profile
3. Set host-local values:
   - listen host/port
   - workspace root
   - secret source path(s)
4. Keep host-only concerns in the host:
   - SOPS secret declarations
   - firewall/proxy rules
   - bind mounts/persistence layout

Minimal host snippet:

```nix
aiServices.nullclawDeployment = {
  enable = true;
  listenHost = "127.0.0.1";
  listenPort = 3001;
  workspaceRoot = "/var/lib/nullclaw";
  environmentFile = config.sops.secrets.nullclaw.path;
  # or:
  # configJsonSource = config.sops.secrets.nullclaw-config.path;
};
```

## Fleet Replication Checklist
1. Keep nullclaw service logic in `modules/services/nullclaw.nix` and host rollout logic in `modules/services/nullclaw-deployment.nix`.
2. Keep host files data-oriented: only set deployment inputs, secrets, proxy/firewall, and persistence.
3. Keep secret handling explicit per host (`environmentFile` or `configJsonSource`), never both unless intentionally required.
4. Keep bind/port explicit per host (`listenHost`, `listenPort`) and verify with smoke checks.
5. Run `task checks:quick` before deployment changes.

## New-Machine Onboarding Checklist
1. Import `modules/services/nullclaw-deployment.nix` in the host module.
2. Enable nullclaw composition (`profiles.aiHost.nullclaw.enable = true` if using `profiles.aiHost`).
3. Set `aiServices.nullclawDeployment` inputs: `enable`, `listenHost`, `listenPort`, `workspaceRoot`.
4. Set host secret wiring:
   - env-file pattern: set `environmentFile` and declare matching SOPS secret.
   - config-file pattern: set `configJsonSource` and declare matching SOPS secret.
5. Keep host-only networking/storage explicit:
   - firewall/proxy rules
   - bind mounts/persistence paths
6. Validate and deploy:
   - `task checks:quick`
   - `task services:deploy:host:<host>`
   - `task checks:nullclaw:smoke:<host> ...` (or host shortcut where available)

## Rollback Checklist
1. Roll back target host generation:
   - `sudo nixos-rebuild switch --rollback`
2. Verify service is healthy:
   - `sudo systemctl status nullclaw`
3. Re-run smoke checks:
   - `task checks:nullclaw:smoke:<host> ...`
4. Revert offending repo commit and redeploy when ready.

## Top Failure Fingerprints
1. `systemctl status nullclaw` shows restart loop.
   - Common cause: unreadable/invalid staged config file from `configJsonSource`.
2. Service is active but `127.0.0.1:3001` listener is missing (or wrong bind/port).
   - Common cause: wrong `listenHost` or `listenPort`.
3. `/run/secrets/...` path missing or unreadable at runtime.
   - Common cause: host SOPS secret declaration/key setup mismatch.
4. Required workspace paths missing (`${workspaceRoot}`, `.nullclaw`, `workspace`).
   - Common cause: host persistence/filesystem assumptions not met.
5. Reverse proxy works but points to wrong backend port/service.
   - Common cause: host nginx/firewall rules not updated consistently with intended exposure.

## Known Limitations / Deferred Items
- No synthetic integration test spins up a VM; checks are eval-time plus host smoke checks.
- Health endpoint path is host/service-version dependent, so smoke task keeps it optional.
- The shared module assumes the service identity from `modules/services/nullclaw.nix` (`systemd.services.nullclaw`, user/group `nullclaw`).
