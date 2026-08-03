# frieren Exceptions

## Scope
NAS server (Samba, NFS, Jellyfin, Paperless-ngx, Unbound DNS + Pi-hole, aria2) and 4K media center (Ideapad). Built in CI by default.

## Key Differences
- **Daily self-upgrade**: canonical `system.autoUpgrade` module (no hand-rolled timer/script) runs at 04:00 every morning with a persistent timer (catches up on next boot if the NAS was off). It stages `nixos-rebuild boot --flake github:shaoyanji/nixconfig#frieren` first, then:
  - kernel/initrd/kernel-modules **changed** → reboots into the new generation (`shutdown -r +1`) — only reached when the boot command exited 0;
  - otherwise → live `nixos-rebuild switch`, no reboot.
  - The `github:` ref fetches the public repo tarball; `modules/secrets.yaml` is a tracked file in the main repo, so eval works without the private `modules/secrets` submodule.
  - `allowReboot = true`, no `rebootWindow` — reboots are allowed any time (04:00 NAS reboot is fine). To constrain reboot time, set `system.autoUpgrade.rebootWindow`.
  - **Don't leave uncommitted local config on frieren** — the self-upgrade pulls from GitHub and will override a dirty local checkout.
- **SOPS**: decrypts `modules/secrets.yaml` via its `ssh_host_ed25519_key` age key (also `aria2-rpc-secret`).
- **Samba/NFS**: exports live under `/export/*` (bind-mounted from `/srv/*`); NFS serves `192.168.3.0/24` + Tailscale `100.64.0.0/10`.

## Operational Interpretation
- Prefer the canonical host deploy flow (`infra:deploy:host:frieren`).
- After the daily autoUpgrade lands, `infra:deploy:host:frieren` is still fine for immediate/manual deploys — the timer just catches drift the next morning.
