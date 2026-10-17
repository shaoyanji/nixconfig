# scratch

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | I/O Diet Lightweight Workstation |
| status | active — In active production as a lightweight desktop operating under a strict I/O diet. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | true |
| in CI | true |
| hardware | Fujitsu ESPRIMO D556 Small Form Factor |
| cpu | Intel Core i5-6500 (Skylake, 4c/4t) |
| gpu | Intel HD Graphics 530 |
| ram | 8 GB DDR4 |
| storage | Legacy BIOS + GRUB (ext4 /boot, f2fs /) |
| persona | I/O Diet Minimalist & RAM-First Steward (tier: lightweight-io-diet) |
| persona hint | You operate on a system with a vulnerable SSD running f2fs. Every disk write is precious. Treat the system almost as a pure ramfs. |

## Module chain

`globalModulesNixos`

## Traits

- traits:
  - strict-io-diet
  - f2fs
  - legacy-bios
  - zram-100
  - tmpfs-caches

## Key services

- services:
  - Niri Wayland Desktop + DMS Greeter
  - zram 100% swap (zero disk swap)
  - tmpfs mounts for /var/log, /tmp, /var/tmp, /var/cache, ~/.cache
  - volatile journald (RAM only, core dumps disabled)
  - weekly fstrim + noatime

## Allowed tasks

- tasks:
  - RAM-resident development tasks
  - Lightweight text editing and browsing
  - Clean memory management

## Constraints

- constraint:
  - ABSOLUTELY MINIMIZE DISK WRITES. Keep all caches and logs in RAM.
  - Do not run heavy builds that write multi-gigabyte store paths.
  - Legacy BIOS GRUB on /dev/sda; never touch systemd-boot.

## Notes

- Lightweight niri desktop (eisen-style) on a Fujitsu ESPRIMO D556 (i5-6500, 8 GB, 128 GB f2fs SSD). Formerly a Steam Remote Play kiosk; Steam dropped in the 2026-09 desktop conversion.
- f2fs has no subvolumes, so the btrfs impermanence module is NOT used: the host config puts every heavy-write dir on tmpfs (zram 100%, journald volatile, fstrim, noatime).
- Legacy BIOS boot: GRUB on /dev/sda, systemd-boot disabled.
