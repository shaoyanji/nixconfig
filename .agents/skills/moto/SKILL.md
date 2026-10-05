---
name: moto
description: Motorola Android (Termux) operations — SSH access, non-interactive command execution, file push/pull, and Charmbracelet Wish/Gum interactive menus. Derived from taskfiles/moto.yml.
---

# moto — Motorola Android (Termux) Control Plane

Control and interact with the Motorola Android phone running Termux over Tailscale.

- **Host / IP**: `100.91.87.86` (Tailscale hostname `tailscale-termux`)
- **Port**: `8022`
- **User**: `u0_301` (Termux sandbox UID)
- **SSH Alias**: `moto` (defined in `~/.ssh/config`)

## Quick Tasks

| Task | Description |
|------|-------------|
| `task moto:ssh` | Interactive SSH shell into Termux on the phone |
| `task moto:exec -- "<cmd>"` | Execute command non-interactively on phone via SSH (agent-friendly) |
| `task moto:push -- <local> [dest]` | Transfer local file/dir to phone (defaults to `storage/downloads/`) |
| `task moto:pull -- <remote> [dest]` | Transfer remote file/dir from phone to local machine (defaults to `./`) |
| `task moto:info` | Query device kernel, uptime, load, and storage metrics |
| `task moto:obsidian:status` | Check Obsidian Git status on the phone |
| `task moto:obsidian:sync` | Pull latest Obsidian notes on the phone |
| `task moto:menu` | Interactive Charmbracelet Gum / Wish menu for quick phone operations |
| `task moto:wishlist` | Open Charmbracelet Wishlist SSH directory |

## Termux Storage Shortcuts

Termux provides symlinks in `~/storage` to Android internal storage:

| Shortcut | Android Native Path |
|----------|---------------------|
| `~/storage/downloads` | `/storage/emulated/0/Download` |
| `~/storage/pictures` | `/storage/emulated/0/Pictures` |
| `~/storage/dcim` | `/storage/emulated/0/DCIM` (Camera) |
| `~/storage/documents` | `/storage/emulated/0/Documents` |
| `~/storage/music` | `/storage/emulated/0/Music` |
| `~/storage/movies` | `/storage/emulated/0/Movies` |
| `~/storage/shared` | `/storage/emulated/0` (Root of internal SD) |

## Agent Usage Examples

```bash
# Query disk space and battery
task moto:exec -- "df -h /data"

# Transfer an APK or PDF directly to phone Downloads
task moto:push -- ./book.pdf

# Pull camera photo from phone
task moto:pull -- storage/dcim/Camera/photo.jpg ./
```
