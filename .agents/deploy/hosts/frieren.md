# frieren Exceptions

## Scope
NAS server (Samba, NFS, Jellyfin, Paperless-ngx, Unbound DNS + Pi-hole, aria2) and 4K media center (Ideapad). Built in CI by default.

## Key Differences
- **Two boot personas**: the default generation is headless (no compositor, greeter, or DisplayLink); the niri media centre is `specialisation.desktop` (`hosts/frieren/desktop.nix`). Self-upgrade stages both, so switching persona needs no rebuild — pick it in the systemd-boot menu.
  - A specialisation is **boot-time only**. `nixos-rebuild switch` (what the 04:00 self-upgrade does when the kernel is unchanged) activates the *headless* toplevel even while the desktop session is running, so a desktop-stack edit needs `nixos-rebuild boot` plus a reboot, then selecting the `desktop` entry.
  - Jellyfin's QuickSync does **not** depend on the persona: VA-API (`hardware.graphics`, `intel-media-driver`, `LIBVA_DRIVER_NAME=iHD`) lives in the base `hosts/frieren/hardware.nix`, and `media-stack.nix` puts the `jellyfin` user in `video`/`render` so `/dev/dri/renderD128` is reachable without relying on a 0666 device node.
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
`nixos-rebuild --rollback`, which needs a channel).
**CAUTION**: Always identify `<N>` with `task infra:generations` or `nixos-rebuild list-generations`!
Never use raw `ls /nix/var/nix/profiles/` — lexicographical sorting puts `system-99-link`
below `system-157-link`, which causes inadvertent deep rollbacks that disable hardware drivers (like `dlm.service`).

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

## Rebuild topology (read before rebuilding this host)

frieren is a laptop-class NAS (11 GiB RAM, 8 threads, btrfs). Its nightly
window is already load-saturated; a rebuild started blind will look "stuck"
and tempt you into a retry loop, which is the failure mode this section exists
to prevent.

**Nightly job matrix (all timers `Persistent = true`):**

| Time                    | Unit                                   | Source of truth                                                |
| ----------------------- | -------------------------------------- | -------------------------------------------------------------- |
| 03:00                   | `agy-nightly-handoff` (user)           | Action-gated `~/HANDOFF.md` via Julia-1; executes cascade only on promotion candidates or on-demand (`task checks:audit:handoff`) |
| 03:00                   | `postgresqlBackup-immich`              | local                                                          |
| 03:28                   | `restic-backups-frieren-burgernas`     | daily SFTP push within DSM 03:25–04:00 power window            |
| 03:30 (+10m jitter)     | `restic-backups-frieren-local`         | local                                                          |
| Sun 01:30 (+30m jitter) | `fleet-warm-cache`                     | **`github:shaoyanji/nixconfig`** — builds 7 active host closures |
| 04:00                   | `nixos-upgrade` (`system.autoUpgrade`) | **`github:shaoyanji/nixconfig#frieren`**                       |
| 05:00 (Daily) / Sun     | `agy-nightly-system` (user)            | Trigger-gated `~/SYSTEM.md`: Mon-Sat quiet reflex (bypasses LLM if nominal), Sunday comprehensive scorecard, or on-demand (`task checks:audit:system`) |
| Sun 06:00               | `nix-optimise`                         | weekly hardlink deduplication across live store paths          |

**The origin-vs-local trap (this is the one that bites):**
`system.autoUpgrade` builds from the **pushed GitHub flake**, not
`/Volumes/data/projects/nixconfig`. Any local `nixos-rebuild switch` from a
dirty tree is therefore **silently reverted by the next 04:00 run** unless the
change is committed **and pushed**. A local switch that produced no new
generation usually means exactly this. Confirm what the 04:00 run used:

```bash
journalctl -u nixos-upgrade -n 40 --no-pager | grep -E 'unpacking|new configuration'
git -C /Volumes/data/projects/nixconfig rev-parse HEAD     # must match the unpacked rev
```

**Rebuild rules:**

1. **At most one `nixos-rebuild` at a time.** Never retry-loop it — six
   concurrent attempts is what caused the 2026-10-07 06:46 incident. If it
   seems slow, _measure_ progress (next point) before touching anything.
2. **After a dirty `flake.lock` bump the closure is re-fetched, not rebuilt.**
   A nixpkgs rev change invalidates every store hash, so expect a multi-GB
   download (tens of minutes on this host). It is not hung. Watch it:
   ```bash
   find /nix/store -maxdepth 1 -newermt '-2 minutes' | wc -l   # >0 = progressing
   ls -l /nix/var/nix/temproots/<nix-pid>                      # mtime advances
   ```
   Fat tail to expect: frieren's closure contains **`paperless-ngx` →
   `python3.14-torch` + `triton-llvm` + `wandb` + `google-cloud-cpp`**
   (`nix why-depends /run/current-system <torch-path>` to re-verify). Cheap
   slimming levers here are worth more than any build tuning.
3. **Do not rebuild in the 03:00–05:30 window** on this host. Also avoid
   Sunday mornings while `fleet-warm-cache` is running.
4. **Load average lies here.** It is dominated by D-state btrfs kworkers and
   `kswapd0`, not CPU. Judge pressure with `free -h` + `vmstat 1 3` (look at
   `si/so`, `wa`, and idle%) — CPU is often 60–90% idle at loadavg 8+.
5. **A killed `nixos-rebuild` leaves an orphaned root `nix build`** that can
   never switch anything but keeps ~2 GB resident. Before retrying:
   ```bash
   pgrep -af 'nix build .*nixosConfigurations'    # kill it if it is an orphan
   ```
6. **After a successful switch, verify state, not vibes:**
   ```bash
   readlink -f /run/current-system
   nixos-rebuild list-generations | tail -3
   systemctl --failed; systemctl --user --failed
   ```

## Wiki stack, cache-warm, hermes, SSH CA

- **Kiwix is declarative** (`hosts/frieren/kiwix.nix`, native
  `services.kiwix-serve`): ZIMs are store paths / `fetchurl` entries, served on
  8088 and reverse-proxied at `http://wiki.frieren.lan`. Data lives in
  `/var/lib/kiwix` (NOT `$HOME` — DynamicUser + ProtectHome can't read
  `/home`); the big ZIMs live only as GC-rooted `/nix/store` paths and
  `library.xml` is force-synced from the declarative copy by the
  `kiwix-library` activation script (tmpfiles `C+` never overwrites — it left
  a stale library until 2026-10-08). Add a new wiki by adding a `fetchurl`
  entry (use `nurl <url>` for
  the hash) + a book entry in `kiwixLibrary`. Never hand-run `kiwix-manage`
  and never hand-roll units under `~/.config/systemd/user/` — they shadow the
  declarative ones (that shadowing broke the gateway on 2026-10-08).
- **Uncached fleet builds (NVIDIA 580 etc. are unfree, never upstream-cached):**
  run `task infra:update:fleet` — flake update → `infra:warm:cache` (build all
  host closures on frieren) → `infra:apply:fleet`. Closures built elsewhere:
  `task infra:cache:push:host:<host>` pushes them into harmonia.
- **hermes-gateway:** never run `hermes gateway install` on frieren; edit the
  unit in `modules/user/ai/hermes-user.nix`. Full checklist in
  `.agents/deploy/hosts/frieren.md`.
- **SSH CA:** every host (incl. frieren) can sign certs — `ssh.ca.enableClient`
  - `rotate-ssh-cert` (1-week user certs, CA key via sops-nix at
    `~/.ssh/user_ca_key`).
