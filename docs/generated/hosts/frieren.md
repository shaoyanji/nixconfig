# frieren

> **Generated — do not edit.** Built from `inventory.toml` by `lib/docs.nix`
> (`nix build .#docs`). Refresh the checked-in copy with `task docs:sync`.


| field | value |
| --- | --- |
| role | Central NAS Mainframe, 4K Media Center & Application Server |
| status | active — In active 24/7 production as the central fleet NAS and service host. |
| kind / arch | nixos / x86_64-linux |
| flake output | true |
| managed | true |
| in CI | true |
| hardware | Lenovo ideapad 320-15IKB (Type 81BG, Laptop-as-Server & Media Center) |
| cpu | Intel Core i5-8250U (Kaby Lake R, 4c/8t, 1.60 GHz base / 3.40 GHz turbo) |
| gpu | Intel UHD Graphics 620 @ 1.10 GHz (QuickSync VA-API H.264/HEVC/H.265 4K) |
| ram | 11.47 GiB DDR4 (4GB soldered + 8GB SO-DIMM) + 13.73 GiB swap (8GB disk + 5.7GB zram) |
| storage | /dev/sdb3 (1TB SSD: 923GB btrfs @root, @home, @nix, @snapshots, docker), /dev/sda2 (2TB HDD: 1.8TB btrfs data pool for /srv/data, /Volumes/data, Paperless, Immich, Media, Transmission) |
| lan | 192.168.3.25 |
| persona | Fleet Mainframe & Storage Steward (tier: server-heavy-io-sensitive) |
| persona hint | You are the central system administrator of the fleet mainframe. Prioritize NAS integrity, media streaming continuity, declarative service management, and cautious I/O discipline. |

## Module chain

`globalModulesNixos`

## Traits

- traits:
  - lan-binary-cache
  - nightly-backup-window
  - btrfs-heavy-io
  - sops-secrets
  - ssh-ca-client
  - media-center-tv
  - niri-wayland
  - dms-greeter

## Key services

- services:
  - Harmonia (LAN binary cache on :5000)
  - Paperless-ngx (:28981, data /srv/data/paperless)
  - Hermes Agent & Gateway (user systemd service)
  - Home Assistant (:8123) + Mosquitto MQTT
  - Kiwix Serve (declarative ZIMs :8088 -> wiki.frieren.lan)
  - Immich Photo Server & ML backend
  - Jellyfin Media Server (:8096)
  - Plex Media Server
  - Aria2 RPC daemon (:6801 + AriaNg web)
  - Paste (pb server at paste.frieren.lan)
  - Vaultwarden
  - Uptime Kuma
  - iVentoy PXE server
  - Samba & NFS export (/srv/data)
  - Syncthing

## Allowed tasks

- tasks:
  - Service maintenance & health auditing
  - SOPS secrets management and rekeying
  - Storage hygiene and permission audits
  - Backup verification and snapshot tracking
  - Fleet binary cache warming and closure pushing

## Constraints

- constraint:
  - NEVER run heavy compilations or rebuilds during the 03:00-05:30 nightly backup window.
  - At most ONE nixos-rebuild at a time; never retry-loop builds.
  - Never edit /var/lib/kiwix by hand; Kiwix is strictly declarative.
  - Always push commits to origin/main so 04:00 system.autoUpgrade does not revert local state.
