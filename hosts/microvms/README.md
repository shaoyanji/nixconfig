# MicroVM SubZeroClaw — operating documentation

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
| Tap | `microvm1` (MAC `02:00:00:00:00:01`) on host bridge `microbr` |
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
| `vm:canary:build` | `nix build .#nixosConfigurations.frieren-canary.config.microvm.declaredRunner -o result-canary` |
| `vm:canary:run` | `sudo scripts/task/run-canary.sh` (run dir `/var/lib/microvms/frieren-canary/run`) |
| `vm:canary:test` | 6-step dogfood test |
| `vm:canary:ssh` | SSH into the guest |
| `vm:canary:agent` | `ssh -t frieren-canary subzeroclaw <prompt>` (default: "echo Hello World from inside the MicroVM sandbox") |
| `vm:canary:stop` | poweroff via SSH |

SSH alias `frieren-canary` is defined in `hosts/frieren/infra-stack.nix`
(-> `192.168.83.10`, `UserKnownHostsFile /var/lib/microvms/.known_hosts`).
`infra-stack.nix` imports `modules/profiles/microvm-host.nix`.

## Host prerequisites (runtime, not repo)

Before the first run, the host needs (created once, not in the repo):
- The `microbr` bridge (`192.168.83.1/24`).
- `/var/lib/microvms/frieren-canary/` (`ssh-host-keys` share + run dir) with a
  fresh ed25519 host key.
- A `microvm` system user (`tap-up` fails with `invalid user "microvm"` without it).

## Endpoint chain

```
canary SubZeroClaw
  -> http://192.168.83.1/eisen/v1/chat/completions
  -> host nginx /eisen/ -> /router/ (local rewrite on Eisen)
  -> Eisen nginx /router/ -> router 127.0.0.1:8000
  -> llama-swap / Jev / Laya
```

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
the `microbr` bridge.
