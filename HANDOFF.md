# thinsandy → frieren NAS Migration Handoff

**Date:** 2026-07-24  
**Author:** Buffy (Freebuff)  
**Status:** Stage 0 complete (eval-only, no build, no deploy)

---

## Migration Goal

Migrate the NAS server from **thinsandy** (Pentium M3010, no transcoding, split-brain drive layout) to **frieren** (i5-8250U, Intel UHD 620 QuickSync, 1TB SSHD + 2TB data drive, laptop battery = built-in UPS).

### Key Decisions

- **Same IP (192.168.3.25)** — frieren inherits thinsandy's IP. Minimal config churn on other hosts.
- **Ollama only for AI** — ZeroClaw/NullClaw stay on thinsandy (or other hosts). Ollama moves later.
- **Staged migration** — NAS services first, AI services later. Safer, less debugging surface.
- **OS on 1TB SSHD, data on 2TB** — clean separation. No split-brain `/nix` like thinsandy had.

---

## Stage 0: Completed (Eval-Only)

All changes are in the Nix config only. Nothing has been deployed or built.

### Files Changed

| File | Change |
|------|--------|
| `flake/host-inventory.nix` | Added frieren entry: `globalModulesContainers` chain, `x86_64-linux` |
| `hosts/frieren/configuration.nix` | Complete rewrite: desktop → NAS server. Imports DNS, media-stack, Paperless, tools, Docker, aria2 from `hosts/thinsandy/`. Lid-close = ignore, consoleblank=60. Laptop profile for auto-cpufreq/UPS. |
| `hosts/frieren/hardware.nix` | New: Intel QuickSync for i5-8250U (UHD 620). `intel-media-driver`, `vpl-gpu-rt`, `intel-compute-runtime` (not legacy). PowerTOP for device power states. |
| `modules/profiles/nas-client.nix` | Added frieren to NFS mount exclusion (NAS doesn't mount itself) |
| `.sops.yaml` | Added `&frierenhost` and `&frieren` age keys + `creation_rules` entries |
| `.github/workflows/nixcachix.yml` | Added frieren to commented build matrix for later cachix warming |

### frieren's Module Stack

```
configuration.nix
  ├── hardware-configuration.nix    (1TB SSHD btrfs: @root, @nix, @home, @snapshots)
  ├── hardware.nix                  (Intel QuickSync + powertop)
  ├── base-node.nix                 (SSH, sops, firewall-baseline, boot, keyd, NM, zramSwap)
  ├── server-hardening.nix          (journald caps, tmp cleanup, /var relocation)
  ├── laptop.nix                    (auto-cpufreq: powersave on battery, performance on AC)
  ├── thinsandy/dns.nix             (Tailscale, Pi-hole, Unbound)
  ├── thinsandy/media-stack.nix     (Immich, *arr, Jellyfin, Plex, Home Assistant, Anki)
  ├── thinsandy/paperless.nix       (Paperless-ngx + Tika + Gotenberg, paperless-fork)
  ├── thinsandy/tools.nix           (System tools)
  ├── thinsandy/networking.nix      (Docker + firewall)
  └── aria2-daemon.nix              (aria2 RPC + AriaNg web UI)
```

### Power Management Stack

| Layer | Setting | Source |
|-------|---------|--------|
| Lid close | `HandleLidSwitch = "ignore"` (all 3 variants) | configuration.nix |
| Screen blank | `consoleblank=60` — kernel blanks VT after 60s idle | configuration.nix |
| CPU governor | auto-cpufreq (powersave on battery, performance on AC) | laptop.nix |
| Device power | powertop (PCI/USB runtime PM, C-states) | hardware.nix |

### Validation

- `nix eval .#nixosConfigurations.frieren.config.networking.hostName` → `"frieren"` ✅
- All NAS services confirmed enabled: serverHardening, aria2-daemon, jellyfin, paperless ✅
- Other hosts' NFS mounts unaffected (poseidon still mounts from 192.168.3.25) ✅
- No deprecation warnings on logind settings ✅
- State version preserved at 26.05 ✅

---

## Manual Steps Required (Before Deploy)

### 1. Rekey SOPS secrets

On your workstation with the `modules/secrets` submodule cloned:

```bash
task infra:sops:update-keys
```

This re-encrypts `secrets.yaml` so frieren's host key can decrypt it.

### 2. Verify SSH CA trust

Frieren inherits `ssh.ca.enable = true` from `base-node.nix`. The CA public key is:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMhAN2tuJ4f8kCbCWehJL+fp5VYrTUQpn2ZWK9RC7XM1
```
Once frieren is deployed, SSH in using a CA-signed cert from any workstation:
```bash
task infra:ssh:rotate-cert
ssh frieren  # or ssh 192.168.3.25
```

### 3. Warm CI cache (optional but recommended)

Uncomment `- frieren` in `.github/workflows/nixcachix.yml` → push. This builds frieren's closure on GitHub's runners and uploads to cachix (shaoyanji), avoiding hours-long compilation on the slow laptop.

---

## TODO: Stage 1 — Drive Migration (Not Started)

After the 2TB drive is physically moved from thinsandy to frieren:

1. Add btrfs subvolume mounts to `hardware-configuration.nix`:
   `/srv/data`, `/srv/public`, `/srv/private`, `/var/lib/transmission`, `/swap`
2. Add bind mounts from `thinsandy/hardware-configuration.nix`:
   - `/var/lib/immich` → `/srv/public/immich`
   - `/media` → `/export/data/media`
   - `/export/{data,public,private}` → `/srv/{data,public,private}`
   - `/var/lib/paperless` → `/srv/data/paperless` (already configured in paperless.nix)
3. Port NFS exports + Samba config. Update NIC name (thinsandy=`eno1`, frieren=?).
4. Port `samba-wsdd` + btrfs `autoScrub`.
5. Add firewall ports: 445, 139, 2049 TCP; 137, 138 UDP.
6. Verify service data directories on /srv/ survive:
   - Jellyfin: `/srv/private/jellyfin`
   - Plex: `/srv/private/plex`
   - Home Assistant: `/srv/private/home-assistant`
   - Paperless: `/srv/data/paperless` → bind to `/var/lib/paperless`
   - aria2: `/srv/data/downloads`
   - Immich: `/srv/public/immich` → bind to `/var/lib/immich`

### Cutover Procedure

1. Shut down NAS services on thinsandy
2. Move 2TB drive physically
3. Set static IP 192.168.3.25 on frieren
4. `task infra:apply:host:frieren`
5. Validate: DNS, NFS, Samba, Jellyfin, Paperless, Home Assistant

---

## TODO: Stage 2 — AI Services (Not Started)

Port Ollama to frieren with Intel QuickSync acceleration. ZeroClaw/NullClaw stay on thinsandy (or another host).

---

## Design Decisions & Rationale

- **Reusing thinsandy modules**: `hosts/thinsandy/dns.nix` etc. are imported directly. No code duplication. When thinsandy is eventually decommissioned, these can be moved to `modules/`.
- **No split-brain**: `/nix` stays on the 1TB SSHD (already in hardware-configuration.nix). Unlike thinsandy where `/nix` was on the data drive with a web of bind mounts.
- **Laptop as UPS**: auto-cpufreq drops to powersave on battery, giving time for graceful shutdown. No external UPS needed.
- **Intel QuickSync**: i5-8250U's UHD 620 supports H.264 + HEVC encode/decode — 4K transcoding finally viable. Uses modern `intel-media-driver` (iHD) and `intel-compute-runtime` (not legacy1).
