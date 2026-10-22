# netbook — fleet nixpkgs, pinned stage-1, push deploy

Alice's travel netbook (N3060, 1.8 GiB, eMMC). It carries no global module
chain: its own configuration is the whole system, plus `inventoryModules`. It is
the only host whose closure is **pushed** rather than pulled — see
[Build ladder](#build-ladder-this-is-the-whole-topology).

## What is pinned, and what is not

The kernel is **not** pinned. `boot.kernelPackages = pkgs.linuxPackages` follows
whatever the fleet's nixpkgs ships (6.18.56 on 2026-10-22), and the host follows
the fleet nixpkgs like every other host.

What is pinned is the **initrd implementation**:

```nix
boot.initrd.systemd.enable = false; # scripted stage-1, not systemd-initrd
```

NixOS 26.11 defaults that option to `true`. Commit `e673777e` (2026-10-22)
dropped the old `inputs.nixpkgs_25_11` pin in favour of the fleet nixpkgs (the
input and its `flake.lock` node were pruned the same day, once nothing
referenced them), which silently changed **two** things at once — kernel 7.1.2 → 6.18.56 *and* scripted
stage-1 → systemd-initrd. Only the second one was fatal:

| | generation 50 (failed) | generation 51 (boots) |
| --- | --- | --- |
| nixpkgs | fleet 26.11 | fleet 26.11 |
| kernel | 6.18.56 | 6.18.56 |
| stage 1 | systemd-initrd | scripted |
| loader marker | `root=fstab` | — |
| initrd | 44.5 MB, `lib/systemd` inside | 27.1 MB, `/init` + modules |
| outcome | no stage-2: **no journal entry for the boot**, blank console | booted, 0 failed units |

The boot-critical modules were present in *both* initrds (`f2fs`, `mmc_block`,
`mmc_core`, `sdhci-acpi`, `sdhci`, `rtsx_pci_sdmmc`), and the ESP copies were
byte-identical to their store paths — so "missing initrd" was never the failure.
The eMMC root mounts fine under 6.18.56 with the scripted stage-1.

Nothing here proves `linuxPackages_latest`; the comment that blamed "newer
kernels" predates this measurement. If nixpkgs ever drops the LTS line, that is
the next thing to boot-test — with the same staged procedure, not by deploying
straight across.

## Diagnosing a boot that never reaches stage 2

A failed boot leaves **no journal entry**: stage 1 died before journald started.
Instruments, all runnable from frieren:

```bash
# authoritative: what does the flake say this host's initrd should be?
nix eval .#nixosConfigurations.netbook.config.boot.initrd.systemd.enable
# an installed system: systemd-initrd is the variant that passes root=fstab
grep -h '^options' /boot/loader/entries/*.conf
# did the machine ever reach stage 2? absent boot id = it did not
ssh root@192.168.3.36 journalctl --list-boots
```

Reading the archive itself needs one fact about its layout: an initrd is
`[microcode cpio][TRAILER][padding to 512][zstd cpio]`, so `cpio -it` on the raw
file stops after the microcode entry and a plain `grep` sees nothing. Find the
zstd magic (`28 b5 2f fd`) after the first `TRAILER!!!` and start there — that
is how the 604-entry scripted initrd and the 2078-entry systemd one were
compared.

`boot.consoleLogLevel = 7` is set on purpose. This machine has no serial port,
and at the previous level 3 a hang was indistinguishable from a frozen screen —
generation 50 died with nothing on the console to read.

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

### Where the desktop config lives

`alice`'s rice is `~/.dotfiles` (a git repo with its own installer), symlinked
into `~/.config`. The flake does not own it, and the host's system packages do
not either — `programs.niri.enable` starts the session, the symlinks shape it.

Putting it under home-manager was tried on 2026-10-22 and reverted, for a reason
that is arithmetic rather than taste: `modules/user/base.nix` +
`modules/user/desktop/niri.nix` build a **4.3 GiB** home generation (niri 695 MiB;
the DMS stack pulls ~3 GiB of Qt/Kirigami/qtdeclarative), while the eMMC has
**4.5 GiB** free at 82 % full — on a host that already sat at 84 % once. Two
ways to make a fleet-owned home fit, neither taken yet:

- turn DMS off for this host and give alice a bar (waybar, ~1.3 GiB total), or
- grow the disk first.

Traps found while trying it, worth knowing before the next attempt:

- **Link files, not directories.** `~/.config/tmux` was a *symlink to a directory*
  in the dotfiles repo, so a directory-level `home.file` wrote into that repo
  instead of out of it.
- **Existing symlinks are skipped when identical, refused when not.**
  `backupFileExtension` only moves real files; a differing symlink is a hard
  "would be clobbered" and the whole activation fails.
- **A failed activation leaves the desktop half-owned.** Removing the links and
  letting activation time out leaves `fuzzel` with no config at all, which looks
  like a white theme, not a missing file. Restore the symlinks before debugging.

### Staging a boot-chain change (the practiced path)

A deploy that changes the kernel or initrd store paths is refused by the guard
on purpose. The way across is deliberate and staged, never one shot:

```bash
# 1. write entries + profile, activate nothing (guarded by ALLOW_KERNEL_CHANGE)
ON_BUILDER=1 REMOTE="$PWD" TARGET=root@192.168.3.36 STAGE=boot \
  ALLOW_KERNEL_CHANGE=1 bash scripts/task/deploy-netbook.sh
# 2. keep the proven generation default until the new entry has booted:
#    read the entries, then point `default` at the proven one
ssh root@192.168.3.36 'grep -H "^version" /boot/loader/entries/*.conf'
ssh root@192.168.3.36 "sed -i 's|^default .*|default <proven-entry>.conf|' /boot/loader/loader.conf"
# 3. boot the new entry; once it reaches stage 2 it IS the running generation —
#    confirm with ACTION=verify (deployed == running) and leave the default there
ON_BUILDER=1 REMOTE="$PWD" TARGET=root@192.168.3.36 ACTION=verify \
  bash scripts/task/deploy-netbook.sh
```

Staging with `STAGE=boot` makes the new generation the loader default, because
`switch-to-configuration boot` installs entries for the *current profile*. That
is why step 2 exists: until the entry is proven, the default must stay on the
generation that boots. Give the test entry a distinguishable `title` while it is
under test, and delete the copy afterwards.

### Build ladder (this is the whole topology)

Frieren evaluates and holds the result; nixbuild.net supplies anything missing;
the netbook only receives. `BUILD` picks how the closure is obtained:

| `BUILD` | Flags on frieren | When |
| --- | --- | --- |
| `auto` (default) | `--max-jobs 0 --builders ""`, then `--max-jobs 0` on failure | the fleet nixpkgs closure is normally already in the caches, unknown gaps still get built |
| `local` | `--builders ""` | fall back to compiling on frieren |
| `remote` (`REMOTE_ONLY=1`) | `--max-jobs 0` | every gap on nixbuild.net, nothing local |

`auto` is the default because the first attempt costs nothing: a substituted
closure completes in seconds without touching the 25 h/month nixbuild budget, and
a deploy that does need work escalates instead of failing.

**Nothing on the netbook pulls, and that is not a bug to fix.** Its paths predate
any LAN cache: the closure is 6.6 GB of things it fetched from `cache.nixos.org`
years ago. Measured 2026-10-22 from the host itself, harmonia is reachable
(`nix-cache-info` answers) and *does* serve the current system — because frieren
built it and harmonia serves frieren's store. What it does **not** serve is the
long tail of old paths, which is why the deploy pushes rather than asking the
host to fetch. `ACTION=preflight` prints the answer for the running system, so
this stays a measurement instead of an assumption.

Measured 2026-10-22: `BUILD=remote` 2m28s; `BUILD=auto` on an unchanged tree
seconds (pure substitution); only the paths the host lacks travel, not the
closure. Staging generation 51 — the scripted initrd added to an otherwise cached
fleet closure — reported "substituting … (no compile)": it escalated to neither
nixbuild.net nor a local build, and copied only the paths the host lacked.

## The two guards (both before anything is copied)

| Guard | Refuses | Override |
| --- | --- | --- |
| boot chain — new kernel/initrd store path ≠ running | exit 3 | `ALLOW_KERNEL_CHANGE=1` |
| `/etc/nixos` drift — `configuration.nix` edited since the last deploy | exit 4 | `ALLOW_CONFIG_DRIFT=1` |
| bus dead after activation — units never restarted | exit 5 | none; fix the bus and re-run |
| `switch-to-configuration` non-zero with a live bus | exit 6 | none; read its output |

Both guards compare `/nix/store/<name>` — the kernel and initrd *output* paths —
not the image files. The built system exposes `kernel`/`initrd` as symlinks into
`…-linux-6.18.56/bzImage`, while the target reports the same symlink resolved, so
the first version compared an output path against a file and refused two deploys
on an identical boot chain before either side was normalized.

The boot-chain guard is the anti-brick check, and it is what catches an
accidental kernel move: with the fleet nixpkgs the default kernel changes without
anyone editing `hosts/netbook/`. The drift guard covers the other direction:
`/etc/nixos` stays on the machine as a fallback, so a local `nixos-rebuild` from
an edited copy would deploy something the flake cannot see. After activating, the
deploy records `system=` and `config-sha256=` in `/etc/nixos/.flake-managed`
(plus a `FLAKE-IS-TRUTH` note), and `ACTION=verify` reports when the running
system or that file no longer matches.

`ACTION=preflight` (or `verify`) is read-only: reachability, what the host is
running, drift against the recorded manifest, failed units, disk, and whether
harmonia actually serves the running system. Run it first when the host comes
online.

## Activation needs a working system bus

`switch-to-configuration` links `/etc` and `/run/current-system` **before** it
asks systemd to restart units. When the system bus cannot reach pid1 the deploy
prints `Failed to subscribe to systemd dbus messages` and stops halfway: the new
system is *current* and the units that changed kept running the old one. Measured
here 2026-10-22 — the switch looked successful (`/run/current-system` moved)
while `dbus-daemon` rejected every message from uid 0 to
`org.freedesktop.systemd1` and `org.freedesktop.login1`, so logind could not
create sessions and nothing restarted. The policy sets in `/etc/dbus-1` were byte-identical before and after,
so this is not a config difference: `systemctl restart dbus.service` restored
`Subscribe`/`ListUnits`, and the reboot into the new generation came up clean.

So the deploy verifies instead of assuming (exit 5 = bus dead after the switch,
exit 6 = switch exited non-zero with a live bus). If exit 5 happens: restart the
bus, re-run the switch — and expect a live desktop session to be gone, because
restarting the bus kills it; a reboot is the clean recovery.

## Launching an activation over ssh

The push uses LAN ssh as root (`root@192.168.3.36`), the same key alice has
(`deployKey`). Measured 2026-10-22: right after a reboot the LAN address can time
out for a minute or two while the interface and `sshd` come up — `ping` succeeds
with ~90–230 ms RTT at the same moment, so the neighbour table is not the test.
Retry `ACTION=preflight` rather than switching `TARGET` to the tailnet.

Who reaches the netbook's tailnet address depends on the source, which is why
"use the tailnet" is not a blanket answer: from **frieren** (tagged) it is
intercepted by Tailscale SSH and hangs on a browser check, while from **delphi**
(an untagged member) the same `root@100.72.110.107` reaches the real sshd and the
deploy key works. The script runs on frieren, so its unattended target stays the
LAN address.

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

Entries for generations whose kernel and initrd were pruned from
`/boot/EFI/nixos` survive a switch and hang when selected. On 2026-10-22 **15 of
22 entries pointed at files that no longer existed** (generations 13–26 and 29);
they were deleted, and generation 50 — the systemd-initrd failure — was deleted
once generation 51 replaced it. Live entries are 45–49 plus 51, and `default` is
the running generation.

Re-check whenever the menu is suspected:

```bash
cd /boot/loader/entries
for f in *.conf; do
  k=$(sed -n 's/^linux //p' "$f"); i=$(sed -n 's/^initrd //p' "$f")
  [ -e "/boot$k" ] && [ -e "/boot$i" ] || echo "dead: $f"
done
```

Deleting a dead `.conf` is safe and needs no rebuild — it points at nothing.
`bootctl set-default`/`set-timeout` do not write `/boot/loader/loader.conf` on
this box (verified 2026-10-22); edit that file directly.

## Rollback

`task infra:rollback:host:netbook` — `nix-env --rollback` on the system profile,
then that generation's `switch-to-configuration switch`. No rebuild, no eval. The
guard asks whether the **profile** moved, so a rollback that lands on the system
already running is a success (fixed 2026-10-22; it used to exit 1 after doing the
work whenever the profile was ahead of the running system — the exact state
`STAGE=boot` leaves behind).

Two things the command does not do for you:

- **The loader default still names the newer generation.** The switcher links
  `/run/current-system` but installs no boot entries, so a reboot undoes the
  rollback. Run `<generation>/bin/switch-to-configuration boot` — the task now
  prints the command — to make it stick.
- **A blind rollback from 51 lands on generation 50**, the systemd-initrd system
  that cannot boot. Read `nix-env -p /nix/var/nix/profiles/system
  --list-generations` first, and use `--switch-generation` when the target
  matters.
