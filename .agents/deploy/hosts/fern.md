# fern Exceptions

## Scope
HP 15 laptop (Ryzen 3 3250U, Vega 3 iGPU, 8 GB RAM) — lightweight niri desktop (scratch-style), autologin, NO Steam.

## Key Differences
- **Desktop chain** — `globalModulesNixos` (niri + `programs.dms-greeter` + role:heim userland) via `base-desktop-environment.nix`. `autoLogin` as devji; `defaultSession = "niri"` (scratch-style). No Steam (not imported) — unlike stark/eisen.
- **AMD APU** — Vega 3 on amdgpu/Mesa; `hardware.enableRedistributableFirmware = true` for APU + laptop WiFi/BT firmware. `hardware-configuration.nix` is hand-written (disko owns fileSystems) — revisit after a real scan.
- **Laptop profile** — `modules/profiles/laptop.nix`: auto-cpufreq (powersave/per-governor on battery, performance on AC) + libinput.
- **Single-disk disko** — `hosts/fern/disko.nix`: ESP 500M + 8G swap + btrfs `/root`,`/nix`. Host uses NVMe SSD (`/dev/nvme0n1`, KIOXIA KBG40ZNV256G) as configured in `flake/host-inventory.nix`.
- **SOPS**: Fully registered in `.sops.yaml` with both host key (`fernhost`) and user age key (`fern`). Local keys reside in `~/.config/sops/age/keys.txt`.
- **NAS Client**: Imports `modules/profiles/nas-client.nix` to automount `/Volumes/data` from `frieren`. Includes recovery drop-in (`StartLimitIntervalSec=0`) and `nas-recover` command to resolve any early-boot network races.

## Maintenance and Diagnostics
```bash
# Check data automount state:
systemctl status Volumes-data.automount Volumes-data.mount

# Recover data mount if network delayed at boot:
nas-recover

# Rebuild local system:
task infra:rebuild:nixos
```

## Operational Interpretation
- Prefer canonical host deploy flow (`infra:deploy:host:fern`).
- No CI build enabled by default — add to Cachix workflows only if this host needs remote cache coverage.
