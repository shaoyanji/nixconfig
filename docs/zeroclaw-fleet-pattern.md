# ZeroClaw Deployment Pattern

## Scope
This pattern standardizes zeroclaw deployment across hosts while keeping host-specific logic explicit.

Shared module:
- `modules/services/zeroclaw-deployment.nix`

## What the Shared Module Does
`aiServices.zeroclawDeployment` wraps `services.zeroclaw.instances.<name>` and provides:
- explicit host input surface for bind/port/workspace
- `environmentFile` + `extraEnvironmentFiles` for secrets
- `settings` passthrough for ZeroClaw config
- shared context/auth/state mounts via `ai-services-mounts.nix`

It does not manage:
- SOPS key material and encrypted payloads
- host networking/reverse-proxy policy
- host persistence/bind mounts

## Required Host Inputs
When `aiServices.zeroclawDeployment.enable = true`, set:
- `listenHost`
- `listenPort`
- `workspaceRoot`

Optional:
- `environmentFile` — primary environment file (e.g. shared secrets)
- `extraEnvironmentFiles` — additional env files for instance-specific secrets
- `settings` — ZeroClaw config (providers, channels, etc.); use `$VAR` references for secrets
- `extraSystemPackages` — packages added to the unit's PATH
- `protectHome` — systemd ProtectHome= hardening
- `bindReadOnlyPaths` — read-only bind-mounts (target = source)

## Add a New Machine
1. Import the module in the host file:
   - `../../modules/services/zeroclaw-deployment.nix` (or equivalent relative path)
2. Enable profile/module as needed:
   - keep `profiles.aiHost.zeroclaw.enable = true` if using the AI host profile
3. Set host-local values:
   - listen host/port
   - workspace root
   - environment file path(s)
   - settings (providers, channels, etc.)
4. Keep host-only concerns in the host:
   - SOPS secret declarations
   - firewall/proxy rules
   - bind mounts/persistence layout

Minimal host snippet:

```nix
aiServices.zeroclawDeployment = {
  enable = true;
  listenHost = "127.0.0.1";
  listenPort = 42617;
  workspaceRoot = "/var/lib/zeroclaw";
  environmentFile = config.sops.secrets.zeroclaw.path;
  settings = {
    channels.telegram = {
      enabled = true;
      bot_token = "$TELEGRAM_BOT_TOKEN";
    };
  };
};
```

## Validation

Similar to NullClaw, verify:
- Service is active
- Workspace directories exist
- Listener is bound to correct host/port
- Secret/config files are readable

## Common Issues

1. **Service restart loop**: Check for missing env vars referenced in `settings`
2. **Missing listener**: Verify `listenHost` and `listenPort` match expected values
3. **Secret path errors**: Ensure SOPS secret declaration and key setup are correct
4. **Missing workspace paths**: Check that persistence/filesystem assumptions are met
5. **Unsubstituted `$VAR` in config.toml**: Verify the variable is defined in one of the unit's EnvironmentFile paths
