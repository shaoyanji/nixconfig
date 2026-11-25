# netbook — fleet nixpkgs, pinned stage-1, push deploy

Alice's travel netbook (N3060, 1.8 GiB, eMMC). It carries no global module
chain: its own configuration is the whole system, plus `inventoryModules`. It is
the only host whose closure is **pushed** rather than pulled — see
[Build ladder](../../../docs/netbook-deploy.md#build-ladder-this-is-the-whole-topology).

## What is pinned, and what is not

The kernel is **not** pinned. `boot.kernelPackages = pkgs.linuxPackages` follows
whatever the fleet's nixpkgs ships (6.18.56 on 2026-10-22), and the host follows
the fleet nixpkgs like every other host.

What is pinned is the **initrd implementation**:

```nix
boot.initrd.systemd.enable = false; # scripted stage-1, not systemd-initrd
```

NixOS 26.11 defaults that option to `true`. Commit `22bc1f40` (2026-10-22)
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

Nothing here proves `linuxPackages_latest`; the comment that blamed "newer kernels"
predates the measurement. If nixpkgs drops the LTS line, boot-test that with the same
staged procedure, not by deploying straight across.

## `pti=off` black-panels this machine

A 2026-10-22 boot-params pass tried `pti=off` as a free-speed knob (the Celeron
N3060 pays for page-table isolation in CPU it does not have). Two generations
carried it — 60 and 62 — and both came back unusable: black panel, no serial
console, no journal to read. Generation 61, identical minus the param, booted
fine, so the param is what is out — not the kernel, not the initrd question
above.

What "unusable" means is unproven: nobody watched a failing boot, so the verdict
is correlation, not a mechanism. A re-test needs someone at the screen — boot a
scratch generation, write down what the console says, then decide. The dormant
candidates beside it in `boot.kernelParams` (`fsck.mode=skip`, `nomodeset`,
`console=tty1`, `quiet`/`loglevel=3`) were never enabled and are not implicated.

Baseline for the re-test on the proven kernel: 3000 fork+exec calls = 22.7 s
(7.6 ms each). If `pti=off` cannot beat that by a margin a kitchen laptop can
feel, the panel risk is not worth paying.

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

The boot-chain staging path, the build ladder, both guards, activation over ssh,
the boot-menu repair and rollback are
[`docs/netbook-deploy.md`](../../../docs/netbook-deploy.md).

### Where the desktop config lives

Two layers now, and the split is the point:

- **The system layer is the flake's** — `profiles.dwlDesktop`
  (`modules/profiles/dwl-desktop.nix`), adopted 2026-10-27 and shared with
  scratch. The compositor and its session wrapper are NixOS's own
  **`programs.dwl`**: this profile passes `package` (the spliced keymap) and
  `extraSessionCommands` (the session exports, the wallpaper, the idle unit and
  the host's autostart lines), and `/etc/xdg/dwl-session` execs
  `lib.getExe cfg.package` — an absolute store path. tty1 autologins as alice
  through getty and the login shell execs that wrapper; there is no display
  manager and niri has left the closure. `profiles.dwlDesktop` also owns the
  launcher (`fleet-menu`), the terminal (foot), notifications (fnott, with the
  palette at `/etc/xdg/fnott/fnott.ini`) and idle/lock (swayidle → waylock).
  The keymap is the fleet's
  `modules/config/dwl/config.h` plus this host's dead-key layer, spliced in from
  `hosts/netbook/dwl-keybinds.h` through the profile's `extraKeybinds` — inserted
  first, because dwl takes the first match; the rent is the bottom row and the
  three free keys beside it, so no fleet chord is shadowed. The table is
  `hosts/netbook/dead-keys.toml` (keymap rows, card, `netbook-keys --json`); each
  dead key is one `TYPED()` chord typed by a single `wtype`: no menu, no clipboard. There is **no bar and no secret
  service**, and that is measured rather than taste: waybar's closure is 1001 MiB
  (zenity alone is 902 MiB of it) against dwl's 345 MiB, and gnome-keyring is
  378 MiB — the table and the four verdicts are in
  [`docs/netbook-rice-port.md`](../../../docs/netbook-rice-port.md).
- **`alice`'s rice is `~/.dotfiles`** (a git repo with its own installer),
  symlinked into `~/.config`, and it still wins wherever it carries a file — XDG
  user config beats `/etc/xdg`. It was written for niri, fuzzel, mako and
  alacritty; the port to the session it actually runs in **landed 2026-10-27**, so
  the rice calls `wmenu` (every menu), `foot` (the launchers), `waylock` (lock)
  and `fnottctl` (the six cards), and none of the retired four is installed any
  more. Two rules keep it there: a card identifies itself by a **unique summary
  title** rather than mako's app name, because `fnottctl list` prints
  `id: <summary>`; and bodies pass through a `strip_span` at the notification
  boundary, because fnott renders only `<b> <i> <u>` and would draw a mako
  `<span foreground=…>` as literal text. Porting the mechanism a binding needs,
  not only its chord, is [[flake/policies.nix#desktop-fork-not-disable]] /
  `rice-fork-not-patch`. The mapping and what it loses:
  [`docs/netbook-rice-port.md`](../../../docs/netbook-rice-port.md).
- **The session's compositor is an absolute path, and that is a lesson bought
  once.** The first version of this profile wrapped the session in its own
  `writeShellApplication` with `pkgs.dwl` among its `runtimeInputs` while the
  *keymap* build went to `systemPackages`. The wrapper's PATH wins inside the
  session, so the deployed compositor was upstream's `config.h`: no bind in this
  repo existed, on either host, and nothing looked wrong — stock dwl renders,
  spawns and tiles. `programs.dwl` execs `lib.getExe cfg.package` instead, which
  no PATH can shadow. Instruments, in order of what they actually answer:
  `grep -a quick-keys.sh /proc/$(pgrep -x dwl)/exe` says whether the **running**
  binary carries the host keymap, while reading the derivation only says it was
  built; `nix-store -q --referrers` on each `dwl-0.9` path says which layer pulled
  which.
- **A Wayland socket file outlives the compositor that made it.** The clients
  (wallpaper, idle/lock, the notifier, the autostart lines) start from a hook that
  runs *before* dwl, so the wrapper waits for the socket — and on a session restart
  dwl is killed rather than exiting, leaving `wayland-0` bound to nothing. The
  first version treated the file as the proof and launched the set against a dead
  socket: `swaybg`, `swayidle` and `mako` all exited while `makobatt -s` and
  `taildrop --daemon` (which never touch Wayland) survived, which reads as "some
  programs are gone" rather than "the session raced". Now `swayidle` starts first
  as a canary and the set only proceeds if it is still up 0.3 s later: a client
  that answers is the proof, the file is only a hint. Measured 2026-10-27 by
  restarting `getty@tty1` — a fresh boot never shows it, because `/run/user/1000`
  starts empty.

Putting it under home-manager was tried on 2026-10-22 and reverted, for a reason
that is arithmetic rather than taste: `modules/user/base.nix` +
`modules/user/desktop/niri.nix` build a **4.3 GiB** home generation (niri 695 MiB;
the DMS stack pulls ~3 GiB of Qt/Kirigami/qtdeclarative), while the eMMC has
**4.5 GiB** free at 82 % full — on a host that already sat at 84 % once. Two
ways to make a fleet-owned home fit. The first is now taken at the **system**
layer, which is where it was cheap: `profiles.dwlDesktop` gives alice dwl without
a 4.3 GiB home generation — but not the bar half of it (below):

- turn DMS off for this host and give alice a bar — dwl done system-side
  2026-10-27; the bar is declined, the home-manager half is still untaken, or
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

### No bar, no secret service

Everything declined on this host was declined with a number: the closure table and
the four verdicts (bar, browser, secret service, display manager) are in
[`docs/netbook-rice-port.md`](../../../docs/netbook-rice-port.md).

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
