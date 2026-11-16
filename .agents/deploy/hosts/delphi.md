# delphi — OCI Ampere A1 provisioning & verification

Contract: `inventory.toml [hosts.delphi]`, `flake/host-inventory.nix`.
Config: `hosts/delphi/{configuration,disko,hardware-configuration}.nix`.
Nothing here is executable truth — the commands are the runbook, the flake is the config.

**Target:** OCI `VM.Standard.A1.Flex`, **2 OCPU / 11 GiB** (measured; the 4 OCPU / 24 GB
figure was the shape ceiling, not what was created), aarch64-linux, 200 GB paravirt
boot volume on `/dev/sda` (GPT/UEFI, confirmed by `lsblk`).
Reached as `ubuntu@92.5.115.103` pre-install, `devji@92.5.115.103` after.

Four jobs: **webserver** (nginx + `/healthz`), **hermes agent** (CLI + gateway,
own Telegram bot), **tailnet resolver** (crab-hole on the shared `10.99.0.53`), and
the **`sandbox` microVM guest** that `/microvm/*` is served from.

## Switching this host from the NAS

`ssh delphi` does not resolve on frieren, and every tailnet form of the name now
lands on **Tailscale SSH**, which demands a browser check per client: measured
2026-11-04 from frieren, `devji@delphi.cloudforest-kardashev.ts.net`,
`devji@100.123.145.53` and `root@…` all answered *"requires an additional
check"* and blocked. The door that works is the **public name** the install
used — `devji@delphi.bountystash.com`, BatchMode-safe over 22, with the fleet
user certificate, NOPASSWD sudo, and `devji` in `wheel` so it is a trusted user
for `nix copy`. Use the name, not the IP it resolves to: `inventory.toml` records
the public IP as ephemeral, so an address that works today can move without a
config change.

delphi is `warmOn = "self"` (`inventory.cache.delphi`): it builds its own
fleet-specific derivations and substitutes the rest from cachix, so no builder is
involved and no push is needed:

```bash
nix flake archive --to ssh://devji@delphi.bountystash.com '.?submodules=1'   # ~1 min
ssh devji@delphi.bountystash.com 'sudo nixos-rebuild switch --flake /nix/store/<src>#delphi'
```

Run the switch **detached** (`systemd-run --unit=… --collect`) so a dropped
connection cannot kill activation mid-way — and give that unit a PATH:
`--setenv=PATH=/run/current-system/sw/bin:/run/wrappers/bin`. Without it
`nixos-rebuild`'s Python dies on `[Errno 2] No such file or directory: 'test'`
**after** a successful build, so the closure is ready and the switch never
happened (measured 2026-11-04; the retry took 9 s because everything was warm).
Check the delta first with `nix build --dry-run --json --builders ""`: an aarch64
paperless rebuild is ~41 minutes, a config-only change is ~18 small derivations.

## Guest layer — the `sandbox` microVM

Declared in `hosts/microvms/guests.nix`; rationale and the traps that shaped it are
in the `AGENTS.nix` note `microvm-guests` (`task ops:notes:show ID=microvm-guests`).

| What | From a workstation | From delphi |
| :--- | :--- | :--- |
| Guest root shell | not reachable (bridge is host-local) | `ssh sandbox`, or `task microvm:ssh NAME=sandbox` |

`ssh delphi.bountystash.com` is the **host** shell as `devji`. `sandbox` resolves only
from delphi because `192.168.83.0/24` is host-local.

The terminal deck (`slides`) is **off**: it is a development facility, not a service,
and it leaked a TUI per abandoned login — under TCG three of them were 0.65 of the box's
two cores. `slidesUser = "slides"` plus `exposeSsh = 2222` in
`flake/host-inventory.nix` brings it back; the module side is still in
`hosts/microvms/guests.nix`.

HTTP lives in the guest too: `/microvm/one/` and `/microvm/two/` (busybox stubs) on
both hostnames, `/microvm/stirling/` on the tailnet only (public answers 302).

## Runtime layer (moved)

The DeepSeek harness, the tailnet service mounts, the three offloaded services, the
Gemini capsule and the compiled dossier/console live in
[`docs/delphi-runtime.md`](../../../docs/delphi-runtime.md). What stays here is how to
reach the host, the guest layer, and what this install fixed.

## Install (moved)

The fresh-install walkthrough — phases 0 to 5, including the OCI security-list
traps and the HTTPS/autoUpgrade path — is [`docs/delphi-install.md`](../../../docs/delphi-install.md).
What a running delphi needs instead is the runtime layer above and the traps below.

## DNS failover topology

Why `10.99.0.53`, what a VIP buys, how the pair is approved: `docs/dns-failover.md`.
delphi is the only member today, so the /32 is served by delphi alone.

## Fixed during this install (they were not config typos)

- `disko` has **no `label` option** on a filesystem content — a stable handle comes from
  the partition `name` (`disk-main-root`, `disk-main-ESP`). Caught by `checks:host MODE=eval`.
- **crab-hole v0.1.12 has no `tcp` downstream protocol** (`udp|tls|https|quic`). No
  DNS-over-TCP, so no truncation retry. Caught only by the build (`validate-config`).
- **`.#homeAgents.<host>` was an x86_64-pinned derivation** (`agentDocs.writeText`), so
  no aarch64 host could build its `~/AGENTS.md`; it is pure text and is now
  `builtins.toFile`. Caught only by the build on the target.
- **User lingering was undeclared fleet-wide** (frieren had `loginctl enable-linger` by
  hand). `users.users.devji.linger = true` on delphi is what lets `hermes-gateway`
  survive logout and start at boot.

## Never on this host

- **The microVM guest test.** It needs `/dev/kvm`, this host has none, and the attempt is a
  known failure; `microvm@test_instance` and its runtime paths are not a fault to chase.
  `checks:units` skips every `microvm*` unit for this reason — leave them alone, do not
  start them to "see what happens".
