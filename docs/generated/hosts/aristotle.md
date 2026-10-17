# aristotle

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | ThinkPad T440 Mobile Laptop Workstation |
| status | active — In active production on LAN as a lightweight ThinkPad T440 mobile laptop workstation. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | true |
| in CI | true |
| hardware | Lenovo ThinkPad T440 (20B7S06N00) |
| cpu | Intel Core i5-4300U (Haswell-ULT, 2c/4t, 1.90 GHz base / 2.90 GHz turbo, 15 W) |
| gpu | Intel HD Graphics 4400 (Haswell-ULT Integrated) |
| ram | 8 GiB DDR3L + 3.8 GiB zram swap |
| storage | 59.6GB Innodisk M.2 (S42) 3ME4 SSD (/dev/sda2 btrfs @root, @home, @nix; /dev/sda1 550MB vfat /boot) + NFS /Volumes/data mount |
| lan | 192.168.3.32 |
| tailnet | 100.110.54.71 |
| persona | Philosophical ThinkPad T440 Mobile Workstation (tier: lightweight-laptop) |
| persona hint | You are the ThinkPad T440 mobile laptop companion. Prioritize energy-conscious operation, snappy Niri Wayland workflows, and seamless LAN NAS integration. |

## Module chain

`globalModulesNixos`

## Traits

- traits:
  - thinkpad-t440
  - laptop-profile
  - niri-desktop
  - nfs-client
  - battery-optimized
  - btrfs

## Key services

- services:
  - Niri Wayland Compositor (autologin devji)
  - DMS Greeter (DankMaterialShell)
  - auto-cpufreq (powersave on battery, performance on AC)
  - libinput touchpad tuning
  - NFS client automount (/Volumes/data from frieren)
  - SSH CA Client

## Allowed tasks

- tasks:
  - Everyday coding and markdown notes
  - NFS synchronization with NAS
  - Lightweight desktop productivity
  - Battery lifecycle management

## Constraints

- constraint:
  - 15W dual-core Haswell i5-4300U processor and 8GB RAM; avoid heavy compilation loops. Always substitute closures from frieren LAN cache.

## Notes

- Lenovo ThinkPad T440 (20B7S06N00) laptop: lightweight Niri Wayland desktop via programs.dms-greeter autologin as devji.
- Intel Core i5-4300U (Haswell-ULT, 2c/4t, 15W), Intel HD Graphics 4400, 8 GiB DDR3L, 3.8 GiB zram swap.
- Storage: 59.6GB Innodisk M.2 (S42) 3ME4 SSD (/dev/sda2 btrfs @root, @home, @nix; /dev/sda1 550MB vfat /boot) + NFS /Volumes/data mount from frieren.
- Network: Dual-NIC LAN with enp0s25 wired (192.168.3.32, MAC 28:d2:44:61:0a:38) and wlp3s0 Wi-Fi (192.168.3.93, MAC 7c:7a:91:1b:47:02). Tailscale enabled on 100.110.54.71. DNS directed to frieren Pi-hole on 192.168.3.25.
- Power: Dual-battery ThinkPad Power Bridge system (BAT0 45N1111 internal, BAT1 45N1127 external).
