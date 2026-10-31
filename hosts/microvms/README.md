# MicroVM SubZeroClaw — operating documentation

> **This guest is a sandbox, not the fleet's promotion gate.** It boots its own
> kernel and root, so it can never fail for the host being deployed. The gate that
> boots a host's real module graph is `task checks:boot HOST=<host>`
> (`flake/boot-checks.nix`); CI runs it for `modules/services/**` changes.

Run SubZeroClaw inside an isolated microVM (the `frieren-canary` guest) while the
LLM inference stays on the host (Eisen). The guest talks only to its host
(`192.168.83.1`), never directly to the LAN. Frieren is the example host
(the canary was proven on Eisen; the same layout applies on frieren, whose
pi-hole maps only bare names).

## Layout

| | |
| :--- | :--- |
| Guest | `hosts/microvms/frieren-canary.nix` (microvm.nix, cloud-hypervisor/KVM) |
| vCPU / RAM | 2 vCPU, 2,048 MB |
| vsock | cid 10 |
| Tap | `microvm1` (MAC `02:00:00:00:00:01`) on host bridge `brlan` |
| Guest IP | `192.168.83.10/24`, gateway `192.168.83.1` (the host), DNS 1.1.1.1 / 8.8.8.8 |
| Virtiofs | host `/nix/store` -> `/nix/.ro-store` (ro) + `/var/lib/microvms/frieren-canary/ssh-host-keys` -> `/etc/ssh/host-keys` (persistent host keys) |
| `/var` | volume (`var.img`, 2,048 MB), writableStoreOverlay `/nix/.rw-store` |
| Kernel | `linuxPackages_6_12`; guest firewall disabled |
| SSH | openssh, ed25519 host key from the share, `PermitRootLogin prohibit-password` |
| User | `devji` (wheel, passwordless sudo, authorizedKeys from config + hardcoded `devji@nixos` key) |
| Guest packages | gcc, gnumake, git, curl, jq, sqlite, procps, htop, python3, file, binutils |
| Dummy API | `canary-dummy-api` (Python HTTP on `0.0.0.0:8080`, JSON health) for Model B reverse-proxy verification |

SubZeroClaw in the guest is a Nix derivation in the same file
(`genlayerlabs/subzeroclaw` rev `6b6b5ad`, `$CC -O2 src/subzeroclaw.c src/cJSON.c -lm`).
The activation script `subzeroclawSetup` seeds `~/.subzeroclaw/{skills,logs}`,
`skills/sandbox.md`, and copies sources to `~/workspace/subzeroclaw`.

## Tasks (`taskfiles/infra.yml`)

| Task | What it does |
| :--- | :--- |
| `vm:canary:build` | builds `.#microvmRunners.frieren-canary` and prints the store path — no `./result-*` symlink |
| `vm:canary:run` | `sudo scripts/task/run-canary.sh` (run dir `/var/lib/microvms/frieren-canary/run`) |
| `vm:canary:test` | `scripts/task/vm-canary-test.sh`: boot → ssh → guest API → host proxy → stop → teardown |
| `vm:canary:status` | hypervisor + tap state (`run-canary.sh --status`) |
| `vm:canary:ssh` | SSH into the guest |
| `vm:canary:agent` | `ssh -t frieren-canary subzeroclaw <prompt>` (default: "echo Hello World from inside the MicroVM sandbox") |
| `vm:canary:stop` | `run-canary.sh --stop`: guest poweroff, then shares + tap |

SSH alias `frieren-canary` is defined in `hosts/frieren/infra-stack.nix`
(-> `192.168.83.10`, `UserKnownHostsFile ~/.ssh/known_hosts_canary` — a
user-writable file, so the pin works for a non-root login).
`infra-stack.nix` imports `modules/profiles/microvm-host.nix`.

## Host prerequisites (runtime, not repo)

The runner asserts these before it touches the host:
- root, `/dev/kvm`, and the `brlan` bridge (`192.168.83.1/24`, networkd).
- **The guest subnet is owned by `brlan` alone.** A second interface carrying
  `192.168.83.0/24` steals the route: on 2026-10-24 a stale hand-made `microbr`
  did exactly that and every packet went to a DOWN bridge while the guest booted
  happily and sshd listened. `run-canary.sh` now refuses to start in that case and
  names the offending interface.
- `microvm1` tap: created and torn down by the runner's own `tap-up`/`tap-down`.
- `/var/lib/microvms/frieren-canary/ssh-host-keys`: created, with a fresh ed25519
  key, by the runner on first boot — it is the guest's persistent identity.

## Endpoint chain

```
canary SubZeroClaw
  -> http://192.168.83.1/eisen/v1/chat/completions
  -> host nginx /eisen/ -> /router/ (local rewrite on Eisen)
  -> Eisen nginx /router/ -> router 127.0.0.1:8000
  -> llama-swap / Jev / Laya
```

**Frieren declares no `microvm.vms`.** The canary is an out-of-band runner
(`microvmRunners.frieren-canary`, started by `scripts/task/run-canary.sh`), so no
`microvm@` unit is enabled for it, nothing starts it at boot, and the guest does
not carry frieren's service tier — it is `base.nix` plus the canary's own dummy
API. The bridge and NAT it needs come from `modules/profiles/microvm-host.nix`,
which `infra-stack.nix` imports directly.

On frieren, the `/eisen/` proxy is in `hosts/frieren/reverse-proxy.nix`
(`frieren.lan` vhost `/eisen/` -> `http://192.168.3.87/router/` with
**`proxy_set_header Host "eisen.lan"`** — required, because Eisen's nginx
routes on the Host header). On Eisen itself, `/eisen/` rewrites to `/router/`
locally (so the same guest config works on either host).

Existing Model B proxy (`hosts/frieren/reverse-proxy.nix`):
`frieren.lan` vhost `/canary/` -> `http://192.168.83.10:8080/`;
vhost `canary.frieren.lan` -> same. Frieren DNS maps only bare names.

## Isolation model

Runner (microVM) and model (Eisen) on different hosts. The microVM talks
only to its host (`192.168.83.1`), never directly to the LAN. The guest has
no direct access to the LAN, the tailnet, or the host's services except the
`/eisen/` endpoint the host nginx exposes.

## Config management

The guest's SubZeroClaw config is written **unconditionally** by the
activation script (the canary is ephemeral; config is managed, not user-edited):

- endpoint `http://192.168.83.1/eisen/v1/chat/completions`
- `request_extra = {"model":"policy:auto"}` (router default = Kolibri)
- `api_key = "none"` — the router forwards it to Jev, Jev rejects it, and
  the router falls back to Laya. Fine for the hi test. A real Jev key needs
  a secret, never in the repo.

## Pre-warm guidance

Pre-warm Kolibri before running SubZeroClaw in the guest. A cold load
(~4-5 min) can exceed SubZeroClaw's 120s curl cap. Warm it by sending a
tiny chat request for Kolibri and waiting for a real generation, then run
the guest.

## Proof (2026-10-17, on Eisen)

- Canary runner built; bridge + run dir + ssh-host-keys + `microvm` user created.
- Guest booted, `192.168.83.10` pinged, SSH worked, SubZeroClaw config verified.
- Inside the guest, `subzeroclaw "just say hi"` exited 0 with `Hi! 👋`
  (session: USER -> tool `echo hi` -> `hi` -> ASST `Hi! 👋`).
  No literal `TURN_COMPLETE` string in the captured output; clean exit 0
  after the final assistant message is the turn completing. Decision fell
  back to Laya as expected (`api_key "none"`).
- Stopped cleanly (`poweroff` via SSH, guest down).

## Teardown

`vm:canary:stop` (poweroff via SSH). The bridge, run dir, and ssh-host-keys
persist on the host for the next run (they are runtime state, not repo).
To fully remove the guest: delete `/var/lib/microvms/frieren-canary/` and
the `brlan` bridge.
