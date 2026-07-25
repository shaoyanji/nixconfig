# frieren — Fleet NAS Server

**Date:** 2026-07-24  
**Status:** Migration complete — frieren is now the active NAS server replacing thinsandy

---

## Overview

**frieren** (Lenovo IdeaPad 320-15IKB, i5-8250U, 8 GB RAM) replaced **thinsandy** (Pentium M3010) as the fleet NAS server. All NAS services (Samba, NFS, Jellyfin, Paperless, aria2, *arr stack, Home Assistant, Pi-hole/Unbound DNS) now run on frieren at `192.168.3.25`.

### Why frieren?

| Feature | thinsandy (retired) | frieren (current) |
|---------|--------------------|--------------------|
| CPU | Pentium M3010 (no HW transcode) | i5-8250U (Intel UHD 620 + QuickSync) |
| Transcoding | Software-only | HW-accelerated H.264 + HEVC/H.265 |
| Storage | 2 TB data drive | 2 TB data drive + 1 TB SSHD OS drive |
| UPS | None | Built-in laptop battery (~60% conservation mode) |
| Power | Desktop PSU | Laptop (powersave always, headless) |
| IP | `192.168.3.25` | `192.168.3.25` (same) |

---

## Module Stack

```
configuration.nix
  ├── hardware-configuration.nix    (1TB SSHD btrfs: @root, @nix, @home, @snapshots;
  │                                   2TB data drive btrfs: data, public, private, transmission)
  ├── hardware.nix                  (Intel QuickSync + powertop)
  ├── base-node.nix                 (SSH, sops, firewall-baseline, boot, keyd, NM, zramSwap)
  ├── server-hardening.nix          (journald caps, tmp cleanup, /var relocation)
  ├── laptop.nix                    (auto-cpufreq)
  ├── dns.nix                       (Tailscale, Pi-hole, Unbound)
  ├── media-stack.nix               (Immich, *arr, Jellyfin, Plex, Home Assistant, Anki)
  ├── paperless.nix                 (Paperless-ngx + Tika + Gotenberg, paperless-fork)
  ├── tools.nix                     (System tools)
  ├── networking.nix                (Docker + firewall)
  └── aria2-daemon.nix              (aria2 RPC + AriaNg web UI)
```

*(Previously in `hosts/thinsandy/` — moved here when thinsandy was decommissioned.)*

---

## Power Management

| Layer | Setting | Source |
|-------|---------|--------|
| Lid close | `HandleLidSwitch = "ignore"` (all 3 variants) | configuration.nix |
| Screen blank | `consoleblank=30` — kernel blanks VT after 30s | `boot.kernelParams` |
| Display off | `frieren-headless` systemd unit — backlight=0, GPU auto | configuration.nix |
| Battery conservation | `frieren-headless` unit — `conservation_mode=1` (~55-60%) | configuration.nix |
| CPU governor | auto-cpufreq — powersave on battery + charger | configuration.nix |
| C-states | `intel_idle.max_cstate=9`, `processor.max_cstate=9` | `boot.kernelParams` |
| i915 power saving | `enable_dc=2`, `enable_psr=2`, `enable_guc=2`, `enable_fbc=1` | `boot.kernelParams` |
| Thermal | `services.thermald` — Intel fan management | configuration.nix |
| Device power | powertop (PCI/USB runtime PM, C-states) | hardware.nix |

---

## Key Configurations

### Storage
- **OS + nix**: 1 TB SSHD (`/dev/sda`) — btrfs subvolumes `@root`, `@nix`, `@home`, `@snapshots`
- **Data**: 2 TB drive (`/dev/sdb`) — migrated from thinsandy, btrfs subvolumes `data`, `public`, `private`, `transmission`
- **Bind mounts**: `/export/{data,public,private}` → `/srv/{data,public,private}`; `/media` → `/export/data/media`

### Services on frieren
| Service | Port | Notes |
|---------|------|-------|
| Samba | 445/139 TCP | Shares: data, private, public |
| NFS | 2049 TCP | `/export` via LAN + Tailscale |
| Jellyfin | — | HW-accelerated transcoding via Intel QuickSync |
| Paperless-ngx | 28981 TCP | Document management |
| Home Assistant | 8123 TCP | Smart home |
| Aria2 + AriaNg | 6801 TCP | Download manager with web UI |
| Pi-hole + Unbound | — | DNS ad-blocking + resolver |
| *arr stack | — | Media management |

### What's **not** on frieren (still on thinsandy or elsewhere)
- NullClaw / ZeroClaw AI agents
- Hermes agent
- Ollama
- xs runtime

---

## Deploying

```bash
nix eval .#nixosConfigurations.frieren.config.networking.hostName  # → "frieren"
task infra:plan:host:frieren                                        # Dry-run build
task infra:apply:host:frieren                                       # Apply
task infra:deploy:host:frieren                                      # Plan + apply + validate

# SSH in (CA-signed cert)
ssh frieren
```

---

## Migration History

### Completed
- ✅ Stage 0 — Eval-only config changes (flake registration, configuration.nix rewrite, hardware.nix)
- ✅ Drive migration — 2 TB drive physically moved from thinsandy to frieren
- ✅ NFS exports + Samba + WSDD — ported and tested
- ✅ Firewall rules — ports opened for all services
- ✅ Btrfs auto-scrub — configured on all filesystems
- ✅ Power management — powersave governor, thermald, i915 power saving, screen off, conservation mode
- ✅ SOPS rekey — frieren's host key can decrypt secrets
- ✅ CI cache — frieren added to build matrix

### Not Yet Deployed
- ❌ Ollama — still on thinsandy (can migrate later if needed)
- ❌ ZeroClaw/NullClaw/hermes — stay on thinsandy or other hosts

---

## Design Decisions

- **Reusing thinsandy modules**: `hosts/thinsandy/*.nix` are imported directly. When thinsandy is fully decommissioned, move them to `modules/services/`.
- **Clean OS/data split**: `/nix` stays on the 1 TB SSHD. No split-brain `/nix` on the data drive like thinsandy had.
- **Laptop as UPS**: auto-cpufreq on powersave + battery conservation mode (~60%) gives time for graceful shutdown. No external UPS.
- **Intel QuickSync**: i5-8250U's UHD 620 with `i915.enable_guc=2` loads GuC/HuC for HW-accelerated HEVC encoding in Jellyfin.
- **Headless operation**: Display backlight off at boot, GPU in auto power-save, `consoleblank=30`.
