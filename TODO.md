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
