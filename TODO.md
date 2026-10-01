# TODO / Handoff

## Current Open Work
1. Documentation alignment completed (April 30, 2026) - All documentation now reflects simplified task control plane and current AI services state. See [AUDIT.md](AUDIT.md) for full details.
2. **nixbuild.net SSH key — BLOCKER before enabling remote builds.** Do NOT flip
   `profiles.nixbuild-client.enable = true` on any dispatching host until the key
   exists and is registered:
   1. Generate it: `ssh-keygen -t ed25519 -f ~/.ssh/nixbuild` (no passphrase —
      the nix daemon must use it unattended).
   2. Register the PUBLIC key in the nixbuild.net console.
   3. Add the PRIVATE key to sops: `task infra:secrets:edit:secrets` →
      `nixbuild_ssh_key: |` (the profile decrypts it to `/root/.ssh/nixbuild`,
      root:0600, and restarts nix-daemon — see
      `modules/profiles/nixbuild-client.nix`).
   4. Only now set `profiles.nixbuild-client.enable = true;` on the dispatching
      host(s) and rebuild. Verify: `nix eval` of `config.nix.buildMachines`,
      `ssh eu.nixbuild.net echo ok`, then `task dev:nixbuild:plan` and
      `task dev:nixbuild:warm` (mind the 25 build-h/month free tier).
3. **frieren follow-up queue** (from the 2026-09-29 service review):
   - Add `services.postgresql.backup` (pg_dump) for Immich's DB and include
     the dump dir in the restic job — `/var/lib/postgresql` is deliberately
     excluded from `infra-stack.nix` (hot data-dir copies are not consistent).
   - MQTT hardening: when real devices arrive, switch mosquitto from the
     loopback-anonymous listener to an authenticated LAN listener with
     passwordFile via sops (see `hosts/frieren/ha-stack.nix` header).
   - restic hardening: move `/root/.restic-password` into sops and add an
     offsite repository target (B2/rest-server) alongside the local one.
   - When a Zigbee coordinator dongle is attached: set
     `services.zigbee2mqtt.settings.serial.port` from `/dev/serial/by-id`.
   - Cheap resilience win: battery-as-UPS sensor for frieren in HA via the
     already-enabled `command_line` integration (`/sys/class/power_supply`).

## Fleet Optimizations (2026-10-01 review)
1. [x] **Local binary cache on frieren.** Run `harmonia` (signed, port 5000)
   on the NAS so LAN hosts share store paths instead of each pulling from
   WAN caches. `modules/services/harmonia.nix` enabled in
   `hosts/frieren/configuration.nix`; `http://192.168.3.25:5000` prepended to
   `nix.settings.substituters` and its key (`frieren.lan-1:BUg+1UmfYlF0…`)
   to `trusted-public-keys` in `modules/global/global.nix`. The private
   signing key was generated once and stored as `harmonia_signing_key` in
   sops (committed to the secrets submodule). Deploy frieren to activate;
   verify with `curl http://192.168.3.25:5000/nix-cache-info`.
2. [x] **Gate the AI stack behind an option.** `roles/minimal.nix` no longer
   unconditionally imports `user/ai`; `user/ai/default.nix` now defines
   `profiles.ai.enable` (default on for desktop/heim roles, off in
   `globalModulesContainers` via `noDE.nix`) so headless container hosts
   (mtfuji, kellerbench, netbook, guckloch, …) drop crush/freebuff/qmd/
   antigravity-cli/translate-shell from their closures.
3. [x] **nixbuild.net remote builder.** Key found at
   `/Volumes/data/security/nixbuild keys/` and stored as
   `nixbuild_ssh_key` in sops (committed to the secrets submodule).
   `profiles.nixbuild-client.enable = true` is on for `frieren` (the
   fleet cache-warmer); eval confirms `nix.buildMachines` targets
   eu.nixbuild.net with the key decrypting to `/root/.ssh/nixbuild`.
   Key registered with the account (default-permissions grant
   build:write, store:read/write). NOTE: do not verify with
   `ssh eu.nixbuild.net echo ok` — arbitrary SSH command execution needs
   the undocumented `run:write` permission, which default-permissions
   refuses to grant. Correct probe:
   `NIX_SSHOPTS="-i <key>" nix store ping --store ssh://eu.nixbuild.net`.
4. [x] **Dedupe `specialArgs` in host-inventory.** `lib/mk-nixos-host.nix`
   now defaults `specialArgs = { inherit inputs self; }` (wired from
   `flake/nixos-configurations.nix`); the 26 per-host copies were removed
   from `flake/host-inventory.nix` (per-host overrides still possible).
5. [x] **Parallel fleet deploy.** New `infra:apply:fleet` task in
   `taskfiles/infra.yml`: takes a `HOSTS` list (defaults to all inventory
   hosts of kind nixos) and fans out `nixos-rebuild --target-host` jobs in
   parallel, streaming each host's output through `nom`.
6. [x] **Nix daemon resiliency tuning.** Added to `nix.settings` in
   `modules/global/global.nix`: `connect-timeout = 5` (fail over to other
   substituters fast), `fallback = true` (build locally when caches are
   unreachable), and `keep-outputs = true` (GC keeps dev-shell closures).
7. [x] **LTS kernel for server-class hosts.** `frieren` now pins
   `boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_12` (the LTS
   track); desktops keep `linuxPackages_latest` from
   `modules/profiles/base-node.nix`.
8. [x] **X11Forwarding off fleet-wide.** Removed from
   `modules/profiles/base-node.nix` — no consumer was using X11 over SSH.
9. [x] **Fleet cache-warmer on frieren.** Shipped as `task infra:warm:cache`
   (builds every host closure locally so harmonia serves them at LAN speed;
   `UPDATE=1` also refreshes `flake.lock` and commits) plus a weekly
   unattended timer on frieren (`fleet-warm-cache`, Sundays 03:30,
   persistent, builds from `github:shaoyanji/nixconfig` like autoUpgrade).
   Note: LTS kernel pin reduces but does not remove reboots — keep
   `allowReboot = true` on frieren so 6.12.x security bumps still get
   applied at 04:00.

## TestVM Follow-Up
1. Inventory every host that embeds or plans to embed `testvm`-style microVM wiring.
   - poseidon's `testvm` microVM is **disabled** (2026-08): the microvm imports and `microvm.vms` block are commented out in `hosts/poseidon/configuration.nix` for easy re-enable.
2. Extend the shared guest baseline only when host-local bridge/share differences stay small.
3. Keep host-local bridge/NAT, bind mounts, persistence, and external interface choices in the host files.
4. Decide whether the standalone `testvm` output should eventually move into `modules/profiles/*` or stay under `hosts/microvms/*`.

## Things To Avoid
- Do not do a broad host rewrite in one pass.
- Do not move secrets or encrypted data.
- Do not silently widen system support.
- Do not assume Garnix persistence.
- Do not merge host-local storage layout into shared modules unless the reuse is clearly real.

## Immediate Next Reasonable Tasks
1. Watch `hosts/common` for new wrapper-only detours and prefer canonical modules or shared profiles when possible.
2. Review `disko` as the remaining architecture exception (documented with design comment).
3. Extend the shared `testvm` baseline only if another host genuinely needs it.
