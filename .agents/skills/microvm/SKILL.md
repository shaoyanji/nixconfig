---
name: microvm
description: "Guests on delphi (declarative sandbox) and frieren (canary runner): the task that boots each, how to get a shell in one, and the traps that make a healthy guest look unreachable."
version: 0.1.0
platforms: [linux]
metadata:
  hermes:
    tags: ['microvm', 'canary', 'sandbox', 'cloud-hypervisor', 'qemu', 'ssh', 'systemd']
---

# microvm — the guests, and the door into each

Two kinds, and the kind decides the tool. Nothing here re-implements the
taskfile: the tasks are the API, this page is the route to them.

| Kind | Where | Lifecycle |
| :--- | :--- | :--- |
| Declarative guest (`microvm.vms.<name>`) | delphi only: `sandbox` — `hosts/microvms/guests.nix`. Frieren declares none: `testvm` and `frieren-canary` are their own host configs, not `microvm.vms` entries | a `microvm@<name>` systemd unit, `autostart` where declared |
| Canary runner (`microvmRunners.frieren-canary`) | `hosts/microvms/frieren-canary.nix`, started by `scripts/task/run-canary.sh` | a transient unit, `frieren-canary-runner` |

Base module: `hosts/microvms/base.nix` (shared store over virtiofs, one tap, one
static address on `brlan`). Rationale, tiers and state volumes: `AGENTS.nix` note
`microvm-guests` (`task ops:notes:show ID=microvm-guests`).

## Tasks

| Task | What it does |
| :--- | :--- |
| `task microvm:list` | this host's guests and their `microvm@` unit state |
| `task microvm:start NAME=<guest>` | start the unit, wait for ssh |
| `task microvm:stop NAME=<guest>` | stop the unit |
| `task microvm:ssh NAME=sandbox` | ssh in — `sandbox` resolves only on the host that runs it |
| `task vm:canary:run` | boot the canary under a transient systemd unit, return once sshd answers |
| `task vm:canary:ssh` | shell inside the canary |
| `task vm:canary:agent -- "<prompt>"` | run subzeroclaw inside the canary |
| `task vm:canary:test` | **gate**: boot → ssh → guest API → host proxy → stop → teardown |
| `task vm:canary:stop` | graceful shutdown, then shares and tap |

## Logging in

- **The deck** is off on delphi, and it is a development facility, not a service:
  `slidesUser` + `exposeSsh` in `flake/host-inventory.nix` bring it back. Plain
  `ssh delphi.bountystash.com` is the **host** shell as `devji`.
- **The canary**: `ssh frieren-canary` from frieren (alias and known-hosts entry in
  `hosts/frieren/infra-stack.nix`), `task vm:canary:ssh` from anywhere with the repo.
- **The sandbox shell**, from delphi: `task microvm:ssh NAME=sandbox` (root in the guest).

## Traps that look like a broken guest

- **A foreground runner dies with its terminal.** `run-canary.sh` tears the guest
  down from its own EXIT trap, so a run started in one shell and abandoned takes the
  guest with it and the next login just times out. `vm:canary:run` now boots under
  `frieren-canary-runner` for exactly this reason; `FOREGROUND=1` restores blocking.
- **Root cannot evaluate the checkout.** `nix build` as root fails libgit2's owner
  check on the repo, so resolve the runner as the invoking user and pass
  `CANARY_RUNNER=<store path>` — that is what the task does.
- **A systemd unit has no PATH and no HOME.** `--setenv PATH=/run/current-system/sw/bin`
  and `HOME=/root`; without the first, the script dies on `dirname`.
- **The guest subnet is host-local.** `192.168.83.0/24` exists only on the hypervisor,
  so `sandbox` / `frieren-canary` mean nothing from another machine.
- **A stale address steals the route.** If another interface holds
  `192.168.83.1/24` (a hand-made `microbr` did), the guest boots, sshd listens and
  nothing answers; `run-canary.sh` refuses to start and names the interface.
- **TCG needs patience.** On delphi (aarch64, no EL2) the handshake takes seconds and
  sops/udev labelled disks need a wider device timeout; a 3 s ssh timeout is a false
  negative.

## Exit

`task vm:canary:test` exits 0 and the guest is gone (`vm:canary:status` says not
running, tap absent); a declarative guest answers `task microvm:ssh NAME=<guest>`
and `systemctl is-active microvm@<guest>` says active.

Truth: `taskfiles/infra.yml` (`microvm:*`, `vm:canary:*`) and `hosts/microvms/` — this
page is procedure.
