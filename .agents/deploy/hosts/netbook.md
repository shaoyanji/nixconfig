# netbook — pinned boot chain, push deploy

Alice's travel netbook (N3060, 1.8 GiB, eMMC). It is a flake host, but the only
one whose boot chain is fixed: **newer kernels produced an initrd this box could
not mount root from**, so the machine builds from `inputs.nixpkgs_25_11` in
`flake.nix`, pinned to the exact revision it boots (25.11.12484.b6018f87da91).
Same revision ⇒ the kernel and initrd derivations are the same store paths the
host already runs, which is what makes a flake deploy safe here.

Moving the host forward means changing that input and **boot-testing it**, not
editing `hosts/netbook/configuration.nix`. The host carries no global module
chain: its own configuration is the whole system, plus `inventoryModules`.

## Deploy

```bash
task infra:apply:host:netbook                               # at home, LAN target
TARGET=root@100.72.110.107 task infra:apply:host:netbook    # travelling (tailnet)
```

`scripts/task/deploy-netbook.sh` stages the tree on frieren, obtains the toplevel
**there**, guards it on the target, `nix copy`s the closure over the LAN, then
activates the **built** system with `nix-env -p /nix/var/nix/profiles/system
--set` + `switch-to-configuration`. No flake evaluation and no compiler on the
netbook — the Celeron never evaluates and never builds.

### Build ladder (this is the whole topology)

Frieren evaluates and holds the result; nixbuild.net supplies anything missing;
the netbook only receives. `BUILD` picks how the closure is obtained:

| `BUILD` | Flags on frieren | When |
| --- | --- | --- |
| `auto` (default) | `--max-jobs 0 --builders ""`, then `--max-jobs 0` on failure | pins are substitutable, unknown gaps still get built |
| `local` | `--builders ""` | fall back to compiling on frieren |
| `remote` (`REMOTE_ONLY=1`) | `--max-jobs 0` | every gap on nixbuild.net, nothing local |

`auto` is the default because the first attempt costs nothing: the pinned 25.11
release is already in the caches, so a deploy that changes nothing still
completes in seconds without touching the 25 h/month nixbuild budget, and a
deploy that does need work escalates instead of failing.

**Nothing on the netbook pulls, and that is not a bug to fix.** Its paths predate
any LAN cache: the closure is 6.6 GB of things it fetched from `cache.nixos.org`
years ago. Measured 2026-10-22 from the host itself, harmonia is reachable
(`nix-cache-info` answers) and *does* serve the current system — because frieren
built it and harmonia serves frieren's store. What it does **not** serve is the
long tail of old paths, which is why the deploy pushes rather than asking the
host to fetch. `ACTION=preflight` prints the answer for the running system, so
this stays a measurement instead of an assumption.

Measured 2026-10-22: `BUILD=remote` 2m28s; `BUILD=auto` on an unchanged tree
seconds (pure substitution); toplevel
`…-nixos-system-netbook-25.11.20260630.b6018f8`, closure 6.6 GB — only the paths
the host lacks travel, not the closure.

## The two guards (both before anything is copied)

| Guard | Refuses | Override |
| --- | --- | --- |
| boot chain — new kernel/initrd store path ≠ running | exit 3 | `ALLOW_KERNEL_CHANGE=1` |
| `/etc/nixos` drift — `configuration.nix` edited since the last deploy | exit 4 | `ALLOW_CONFIG_DRIFT=1` |
| bus dead after activation — units never restarted | exit 5 | none; fix the bus and re-run |
| `switch-to-configuration` non-zero with a live bus | exit 6 | none; read its output |

The boot-chain guard is the anti-brick check. The drift guard covers the other
direction: `/etc/nixos` stays on the machine as a fallback, so a local
`nixos-rebuild` from an edited copy would deploy something the flake cannot see.
After activating, the deploy records `system=` and `config-sha256=` in
`/etc/nixos/.flake-managed` (plus a `FLAKE-IS-TRUTH` note), and `ACTION=verify`
reports when the running system or that file no longer matches.

`ACTION=preflight` (or `verify`) is read-only: reachability, what the host is
running, drift against the recorded manifest, failed units, disk, and whether
harmonia actually serves the running system. Run it first when the host comes
online.

## Activation needs a working system bus

`switch-to-configuration` links `/etc` and `/run/current-system` **before** it
asks systemd to restart units. When the system bus cannot reach pid1 the deploy
prints `Failed to subscribe to systemd dbus messages` and stops halfway: the new
system is *current* and the units that changed kept running the old one. Measured
here 2026-10-22 — the switch looked successful (`/run/current-system` moved,
`generation 49` current) while `dbus-daemon` rejected every message from uid 0 to
`org.freedesktop.systemd1` and `org.freedesktop.login1`, so logind could not
create sessions and nothing restarted. The policy sets in `/etc/dbus-1` were
byte-identical before and after, so this is not a config difference: whatever put
the daemon in that state, `systemctl restart dbus.service` restored
`Subscribe`/`ListUnits`, and the reboot into the new generation came up clean.

So the deploy now verifies instead of assuming (exit 5 = bus dead after the
switch, exit 6 = switch exited non-zero with a live bus). If exit 5 happens:
restart the bus, re-run the switch — and expect a live desktop session to be
gone, because restarting the bus kills it; a reboot is the clean recovery.

## Launching an activation over ssh

The push uses LAN ssh as root (`root@192.168.3.36`), the same key alice has
(`deployKey`). Measured 2026-10-22: right after a reboot the LAN address can time
out for a minute or two while the interface and `sshd` come up — `ping` succeeds
with ~90–230 ms RTT at the same moment, so the neighbour table is not the test.
Retry `ACTION=preflight` rather than switching `TARGET` to the tailnet.

## Preconditions

- **Root ssh by key from frieren.** `nix copy` writes to the store, so it needs
  root, and the key is declared in `configuration.nix` (`deployKey`, the same one
  alice has). If root does not have it yet the push fails before touching
  anything; add it once with `ssh alice@… 'sudo tee -a /root/.ssh/authorized_keys'`.
- **Port 22 is Tailscale SSH, i.e. check-gated.** Measured 2026-10-22: `ssh
  root@100.72.110.107` answers "Tailscale SSH requires an additional check" with
  a login URL and then hangs, exactly like delphi. The LAN address
  (`root@192.168.3.36`) hits the real sshd and needs no check — which is why the
  deploy targets the LAN and why nothing unattended may use the tailnet name.
- **`/etc/nixos` is a fallback, not the source.** Nothing updates it any more.

## Boot menu

A switch writes an entry per live generation, but entries for generations whose
kernel and initrd were pruned from `/boot/EFI/nixos` survive it. On 2026-10-22
that meant **15 of 22 entries pointed at files that no longer existed**
(generations 13–26 and 29, from the 26.05 Yarara and 26.11 Zokor experiments) —
paths that look like boot options and hang instead. They were deleted after the
first flake deploy; the seven that remain (27, 28, 45–49) all resolve, and
`default` is the running generation.

Re-check whenever the menu is suspected:

```bash
cd /boot/loader/entries
for f in *.conf; do
  k=$(sed -n 's/^linux //p' "$f"); i=$(sed -n 's/^initrd //p' "$f")
  [ -e "/boot$k" ] && [ -e "/boot$i" ] || echo "dead: $f"
done
```

Deleting a dead `.conf` is safe and needs no rebuild — it points at nothing.

## Rollback

`task infra:rollback:host:netbook` — `nix-env --rollback` on the system profile,
then that generation's `switch-to-configuration switch`. No rebuild, no eval.
