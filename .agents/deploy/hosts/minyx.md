# minyx — Pi 3B jump box, sd-image build

The Pi is not deployed with `infra:deploy`; it takes an image, and the image is
built anywhere but there.

## In flight (2026-10-26)

`nix build .#nixosConfigurations.minyx.config.system.build.sdImage` runs on
**delphi**, detached, from commit `e57537f6`:

| | |
|---|---|
| wrapper | `~/minyx-build.sh` on delphi |
| log | `~/minyx-sdimage.log` on delphi |
| started | 2026-10-26T10:57:51+01:00 |
| flags | `-L --builders "" --print-out-paths` — local compile, cannot bill nixbuild.net |
| done marker | `EXIT=<code>` plus a timestamp as the last lines |

```bash
ssh delphi.bountystash.com 'tail -5 ~/minyx-sdimage.log; pgrep -fa "nix build" | head -2'
```

The run is long because the kernel comes from nixos-hardware
(`linux-rpi-…-stable`), not from `cache.nixos.org`, so delphi compiles it on two
OCPUs. The finished image is `<out>/sd-image/*.img.zst`; nothing has booted it
yet.

## Image layout

`hosts/minyx/hardware-configuration.nix` imports the **generic**
`installer/sd-card/sd-image.nix`, not `sd-image-aarch64.nix`. The aarch64
wrapper also imports `nixos/modules/profiles/base.nix` — the minimal
installation CD's package list — which cost 70 MB of direct packages (vim alone
46 MB) plus samba via `cifs-utils`, and nine filesystem types.

Ownership of the two halves:

- FAT firmware partition: nixos-hardware's `raspberry-pi` module, which sets
  `sdImage.populateFirmwareCommands` with `mkForce`. A firmware block written in
  the host file is dead code.
- `/boot` on the root partition: the host file, via
  `sdImage.populateRootCommands` and extlinux. That is the piece
  `sd-image-aarch64.nix` used to supply, and the one thing to suspect first if
  the image does not boot.

`sd-image.nix` also forces `hardware.enableAllHardware = true`, which implies
`enableRedistributableFirmware`: `linux-firmware` at 1.98 GB for a board with one
Broadcom SDIO radio. `custompi.nix` forces it off and keeps the all-hardware
kernel modules, which the initrd needs to find a root disk on USB.

## Measured

Same-basis cache walk (systemPackages + kernel, narinfo over HTTPS, no build):

```
with profiles/base   344 paths  1.31 GB
without              240 paths  0.85 GB      systemPackages 166 → 133
```

- `vim` 46 MB, removed with the profile; `programs.nano.enable` defaults true,
  so an editor remains.
- `python3` 147 MB was transitive — `git` was the largest referrer — and
  `gitMinimal` (34 paths / 0.19 GB) drops it.
- `helix` is 297 MB on aarch64 against vim's 46 MB. Adding it is one line in
  `custompi.nix` and a quarter of the image.
- `binutils` is absent, so there is no `ld`: `pip install` of anything with C
  extensions cannot build on the box.

## Traps

- **The eval gate does not force option values.** `checks:host HOST=minyx
  MODE=eval` passes on a config with a duplicate option definition (it caught
  nothing when `nix.gc.options` was defined in both `custompi.nix` and
  `modules/global/global.nix`), because a conflict is only detected when the
  value is read. A build, or a forced toplevel, is the only proof.
- The host had no system account before this work — only a Home Manager user
  entry — so a preserved config was never loginable.
- Flashing needs two inputs at the time: the USB device name, and the age
  recipient, which only exists after the first boot from the host key. Sops and
  the Tailscale auth key therefore land in a second commit.
