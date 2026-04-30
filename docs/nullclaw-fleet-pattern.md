# Nullclaw Deployment Pattern

## Scope
This pattern standardizes nullclaw deployment across hosts while keeping host-specific logic explicit.

Shared module:
- `modules/services/nullclaw-deployment.nix`

## What the Shared Module Does
`aiServices.nullclawDeployment` wraps `aiServices.nullclaw` and provides:
- explicit host input surface for bind/port/workspace + secret/config mode
- optional staging of a runtime `config.json` into `workspaceRoot/.nullclaw`
- a single place for fleet-safe nullclaw host wiring

It does not manage:
- SOPS key material and encrypted payloads
- host networking/reverse-proxy policy
- host persistence/bind mounts

## Required Host Inputs
When `aiServices.nullclawDeployment.enable = true`, set:
- `mode` (`none` | `env-file` | `config-json`)
- `listenHost`
- `listenPort`
- `workspaceRoot`

Optional:
- `environmentFile` (required only for `mode = "env-file"`)
- `configJsonSource` (required only for `mode = "config-json"`)

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
  mode = "env-file";
  listenHost = "127.0.0.1";
  listenPort = 3001;
  workspaceRoot = "/var/lib/nullclaw";
  environmentFile = config.sops.secrets.nullclaw.path;
  # or:
  # configJsonSource = config.sops.secrets.nullclaw-config.path;
};
```

## Deployment Modes

### env-file mode
Sets `environmentFile` for nullclaw service. The secret file should contain key=value pairs.

```nix
aiServices.nullclawDeployment = {
  enable = true;
  mode = "env-file";
  listenHost = "127.0.0.1";
  listenPort = 3001;
  workspaceRoot = "/var/lib/nullclaw";
  environmentFile = config.sops.secrets.nullclaw.path;
};
```

### config-json mode
Stages a `config.json` file into `${workspaceRoot}/.nullclaw/config.json` from the specified source.

```nix
aiServices.nullclawDeployment = {
  enable = true;
  mode = "config-json";
  listenHost = "127.0.0.1";
  listenPort = 3001;
  workspaceRoot = "/var/lib/nullclaw";
  configJsonSource = config.sops.secrets.nullclaw-config.path;
};
```

## Current Hosts

### thinsandy
- Mode: env-file
- Listen: `127.0.0.1:3001`
- Workspace: `/var/lib/nullclaw`
- Full AI stack (nullclaw + hermes-agent + ollama + xs + pancakes-harness)

### mtfuji
- Mode: env-file
- Listen: `127.0.0.1:3001`
- Workspace: `/var/lib/nullclaw`
- nullclaw + ollama only (hermes disabled)

### garnixMachine
- Mode: config-json
- Listen: `127.0.0.1:3001`
- Workspace: `/var/lib/nullclaw`
- Minimal nullclaw-only host with nginx proxy

## Validation

Smoke checks are available via `task checks:nullclaw:smoke:<host>`:
```bash
task checks:nullclaw:smoke:thinsandy
task checks:nullclaw:smoke:mtfuji
task checks:nullclaw:smoke:garnixMachine
```

These checks verify:
- Service is active
- Workspace directories exist
- Listener is bound to correct host/port
- Secret/config files are readable
- Optional health endpoint (if configured)

## Deployment Workflow

Standard deployment using the task control plane:
```bash
task infra:plan:host:<host>     # Build/evaluate host closure
task infra:apply:host:<host>    # Apply configuration
task checks:nullclaw:smoke:<host>  # Validate deployment
```

Or use the combined deploy command:
```bash
task infra:deploy:host:<host>   # Plan + apply + validate
```

## Common Issues

1. **Service restart loop**: Check for unreadable/invalid staged config file in config-json mode
2. **Missing listener**: Verify `listenHost` and `listenPort` match expected values
3. **Secret path errors**: Ensure SOPS secret declaration and key setup are correct
4. **Missing workspace paths**: Check that persistence/filesystem assumptions are met
5. **Proxy misconfiguration**: Verify nginx/firewall rules match intended exposure