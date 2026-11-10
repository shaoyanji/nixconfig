# frieren-canary — the runbook sandbox

> **A sandbox, not a gate and not a second frieren.** It boots its own kernel and
> root, so it can never fail for the host being deployed (that is
> `task checks:boot HOST=<host>`), and it imports no host chain, so it carries none
> of frieren's service tier.

An agent boots this guest to run a runbook against a real systemd/ssh machine —
package installs, unit ordering, ssh/PAM behaviour, a script that expects
`systemctl` — and then throws the guest away.

```bash
task vm:canary:run          # transient unit, returns once sshd answers
task vm:canary:ssh          # run the runbook here
task vm:canary:stop         # guest poweroff, then shares and tap
```

## Layout

| | |
| :--- | :--- |
| Guest | `hosts/microvms/frieren-canary.nix` (microvm.nix, cloud-hypervisor/KVM) |
| vCPU / RAM | 2 vCPU, 2,048 MB |
| vsock | cid 10 |
| Tap | `microvm1` (MAC `02:00:00:00:00:01`) on host bridge `brlan` |
| Guest IP | `192.168.83.10/24`, gateway `192.168.83.1` (the host), DNS 1.1.1.1 / 8.8.8.8 |
| Virtiofs | host `/nix/store` -> `/nix/.ro-store` (ro) + `/var/lib/microvms/frieren-canary/ssh-host-keys` -> `/etc/ssh/host-keys` (persistent identity) |
| `/var` | volume (`var.img`, 2,048 MB): survives a restart, unlike `/` |
| Kernel | `linuxPackages_6_12`; guest firewall disabled (it sits behind the host's NAT) |
| SSH | openssh, ed25519 host key from the share, `PermitRootLogin prohibit-password` |
| User | `devji` (wheel, passwordless sudo, keys from `config.ssh.authorizedKeys` + the workstation key the alias uses) |
| Packages | gcc, gnumake, git, curl, jq, sqlite, procps, htop, python3, file, binutils |

There is no service in this list on purpose. The guest's whole unit set is base
plumbing plus `sshd`; check it rather than trusting this page:

```bash
nix eval --json '.?submodules=1#nixosConfigurations.frieren-canary.config.systemd.services' \
  --apply 's: builtins.attrNames s' | jq -r '.[]' | grep -v '^systemd-'
```

## Not always on

Frieren declares no `microvm.vms.frieren-canary` (that is delphi's `sandbox`,
`hosts/microvms/guests.nix`), so no `microvm@` unit is enabled, nothing starts the
canary at boot, and no timer boots it. It exists only while the transient unit
holds it:

- `task vm:canary:run` runs `scripts/task/run-canary.sh` under
  `frieren-canary-runner`, with `RuntimeMaxSec` (`LIFETIME`, default `2h`) so an
  abandoned sandbox expires instead of sitting on 2 GiB of an 8 GiB NAS.
- `vm:canary:stop` is the explicit exit: guest poweroff through the runner's own
  `microvm-shutdown`, then SIGTERM to the supervisord group, then `tap-down`.

Frieren carries **no proxy route** to it. The `/canary/` location and
`canary.frieren.lan` vhost were EXP-102 dogfooding; a vhost for a guest that is
usually down is a per-host surface answering 504. A test that needs HTTP runs its
own listener inside the guest and reaches it over the host-local bridge.

## Tasks (`taskfiles/infra.yml`)

| Task | What it does |
| :--- | :--- |
| `vm:canary:build` | builds `.#microvmRunners.frieren-canary` and prints the store path — no `./result-*` symlink |
| `vm:canary:run` | boots under `frieren-canary-runner`; run dir `/var/lib/microvms/frieren-canary/run` |
| `vm:canary:test` | **gate**: boot → ssh → hostname + declared address → tool set and `/var` → stop → teardown |
| `vm:canary:status` | hypervisor + tap state (`run-canary.sh --status`) |
| `vm:canary:ssh` | SSH into the guest |
| `vm:canary:stop` | `run-canary.sh --stop`: poweroff, then shares + tap |

The `frieren-canary` ssh alias lives in `hosts/frieren/infra-stack.nix`
(-> `192.168.83.10`, `UserKnownHostsFile ~/.ssh/known_hosts_canary`, a
user-writable file so the pin works for a non-root login). `infra-stack.nix`
imports `modules/profiles/microvm-host.nix` for the bridge and NAT.

## Host prerequisites (runtime, not repo)

The runner asserts these before it touches the host:

- root, `/dev/kvm`, and the `brlan` bridge (`192.168.83.1/24`, networkd).
- **The guest subnet is owned by `brlan` alone.** A second interface carrying
  `192.168.83.0/24` steals the route: on 2026-10-24 a stale hand-made `microbr`
  did exactly that, and every packet went to a DOWN bridge while the guest booted
  happily and sshd listened. `run-canary.sh` refuses to start and names the
  offending interface.
- `microvm1` tap: created and torn down by the runner's own `tap-up`/`tap-down`.
- `/var/lib/microvms/frieren-canary/ssh-host-keys`: created, with a fresh ed25519
  key, by the runner on first boot — the guest's persistent identity.

## Removing it

`vm:canary:stop`, then delete `/var/lib/microvms/frieren-canary/`. The `brlan`
bridge belongs to `modules/profiles/microvm-host.nix`, not to this guest: leave it
if anything else on the host uses the bridge.

## The deck login

The guest user's `Match` block is the last entry in `sshd_config`, the only place
a `Match` may appear. The login is the deck: no shell to escape to, no
forwarding, and the deck itself is a read-only store path.

`AuthorizedKeysFile` names every path explicitly, because the directive replaces
the default list instead of adding to it: NixOS writes a user's keys to
`/etc/ssh/authorized_keys.d/<user>`, not to the home directory, so that entry has
to be named back. The hop key comes from the shared directory, which is how the
host-side door reaches the account. A guest user accepts either key and neither
is a password.
