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
- **Samba/NFS**: exports live under `/export/*` (bind-mounted from `/srv/*`); NFS serves `192.168.3.0/24` + Tailscale / 100.* subnet `100.0.0.0/8`.

## Deploy Checklist
- [ ] **Fleet flake update?** Run `task infra:update:fleet` (update → warm
  harmonia → apply) so NVIDIA-580 clients (stark/ares/kellerbench/poseidon)
  never hit uncached builds. Closures built elsewhere: `task
  infra:cache:push:host:<host>`.
- [ ] **Never run `hermes gateway install` on frieren.** It rewrites
  `~/.config/systemd/user/hermes-gateway.service` as a raw (non-store) file,
  which makes Home Manager's `checkLinkTargets` abort the whole switch with
  `Existing file ... would be clobbered` (seen 2026-10-08, restart counter 466
  crash-loop before that). The gateway service is declared in
  `modules/user/ai/hermes-user.nix` (`systemd.user.services.hermes-gateway`);
  edit the unit there, not via the generator. If the install command ran
  anyway, the `hermesGatewayUnitCleanup` activation step removes the stray
  unit before the link check — just redeploy. If a deploy still fails with
  `would be clobbered`, check for other non-store files HM is asked to manage.
- [ ] **Kiwix wiki stack is declarative** (`modules/services/kiwix.nix`, served
  at `http://wiki.frieren.lan`, data in `/var/lib/kiwix`). Add new ZIMs there
  (`nurl` for hashes) — never `kiwix-manage` and never hand-rolled user units
  under `~/.config/systemd/user/` (they shadow the declarative ones).

## nginx activations fail *after* the switch — preflight the config instead (2026-10-19)

Two separate defects made `nginx.service` restart into a crash loop on
2026-10-19, each one AFTER the system had switched (so the rollback is
`/nix/var/nix/profiles/system-<N>-link/bin/switch-to-configuration switch`, not
`nixos-rebuild --rollback`, which needs a channel):

1. **`{8}` in a location key** was emitted as `location ~* \.[a-f0-9] {` +
   `8` + `}` — nginx: `unexpected "}"`. Both occurrences
   (`hosts/frieren/reverse-proxy.nix`, `modules/services/uds-static-bridge.nix`)
   now spell the eight hex digits out. Any future regex location must either
   avoid a brace quantifier or quote the regex, as the `~ "^/([a-z0-9]{8}…)"`
   vhost already does.
2. **`listen … ssl = true` without `addSSL = true`** declares the TLS listener
   but the module never emits `ssl_certificate` — nginx: `no "ssl_certificate"
   is defined`. Set `addSSL` on any vhost that listens on 443.

Preflight before switching — this catches both, and costs one toplevel build:

```bash
nix build --builders "" .#nixosConfigurations.frieren.config.system.build.toplevel -o /tmp/frieren-next
CONF=$(readlink -f /tmp/frieren-next/etc/nginx/nginx.conf)
sudo /nix/store/*-nginx-1*/bin/nginx -t -c "$CONF"   # want: "syntax is ok"
```

A pid-file error (`/run/nginx/nginx.pid`) after `syntax is ok` is expected when
run outside systemd; a syntax or `ssl_certificate` error is real.

## Operational Interpretation
- Prefer the canonical host deploy flow (`infra:deploy:host:frieren`).
- After the daily autoUpgrade lands, `infra:deploy:host:frieren` is still fine for immediate/manual deploys — the timer just catches drift the next morning.
