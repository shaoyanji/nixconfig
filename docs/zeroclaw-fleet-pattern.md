# ZeroClaw Deployment Pattern

## Scope
This pattern standardizes zeroclaw deployment across hosts while keeping host-specific logic explicit.

Shared module:
- `modules/services/zeroclaw-deployment.nix`

## What the Shared Module Does
`aiServices.zeroclawDeployment` wraps `aiServices.zeroclaw` and provides:
- explicit host input surface for bind/port/workspace + secret/config mode
- optional staging of a runtime `config.toml` into `workspaceRoot/.zeroclaw`
- a single place for fleet-safe zeroclaw host wiring

It does not manage:
- SOPS key material and encrypted payloads
- host networking/reverse-proxy policy
- host persistence/bind mounts

## Required Host Inputs
When `aiServices.zeroclawDeployment.enable = true`, set:
- `mode` (`none` | `env-file` | `config-toml`)
- `listenHost`
- `listenPort`
- `workspaceRoot`

Optional:
- `environmentFile` (required only for `mode = "env-file"`)
- `configTomlSource` (required only for `mode = "config-toml"`)

## Add a New Machine
1. Import the module in the host file:
   - `../../modules/services/zeroclaw-deployment.nix` (or equivalent relative path)
2. Enable profile/module as needed:
   - keep `profiles.aiHost.zeroclaw.enable = true` if using the AI host profile
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
aiServices.zeroclawDeployment = {
  enable = true;
  mode = "env-file";
  listenHost = "127.0.0.1";
  listenPort = 42617;
  workspaceRoot = "/var/lib/zeroclaw";
  environmentFile = config.sops.secrets.zeroclaw.path;
  # or:
  # configTomlSource = config.sops.secrets.zeroclaw-config.path;
};
```

## Deployment Modes

### env-file mode
Sets `environmentFile` for zeroclaw service. The secret file should contain key=value pairs.

```nix
aiServices.zeroclawDeployment = {
  enable = true;
  mode = "env-file";
  listenHost = "127.0.0.1";
  listenPort = 42617;
  workspaceRoot = "/var/lib/zeroclaw";
  environmentFile = config.sops.secrets.zeroclaw.path;
};
```

### config-toml mode
Stages a `config.toml` file into `${workspaceRoot}/.zeroclaw/config.toml` from the specified source.

```nix
aiServices.zeroclawDeployment = {
  enable = true;
  mode = "config-toml";
  listenHost = "127.0.0.1";
  listenPort = 42617;
  workspaceRoot = "/var/lib/zeroclaw";
  configTomlSource = config.sops.secrets.zeroclaw-config.path;
};
```

## Validation

Similar to NullClaw, verify:
- Service is active
- Workspace directories exist
- Listener is bound to correct host/port
- Secret/config files are readable

## Common Issues

1. **Service restart loop**: Check for unreadable/invalid staged config file in config-toml mode
2. **Missing listener**: Verify `listenHost` and `listenPort` match expected values
3. **Secret path errors**: Ensure SOPS secret declaration and key setup are correct
4. **Missing workspace paths**: Check that persistence/filesystem assumptions are met
