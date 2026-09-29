# fern Exceptions

## Scope
HP 15 laptop (Ryzen 3 3250U, Vega 3 iGPU, 8 GB RAM) — lightweight niri desktop (scratch-style), autologin, NO Steam.

## Key Differences
- **Desktop chain** — `globalModulesNixos` (niri + `programs.dms-greeter` + role:heim userland) via `base-desktop-environment.nix`. `autoLogin` as devji; `defaultSession = "niri"` (scratch-style). No Steam (not imported) — unlike stark/eisen.
- **AMD APU** — Vega 3 on amdgpu/Mesa; `hardware.enableRedistributableFirmware = true` for APU + laptop WiFi/BT firmware. `hardware-configuration.nix` is hand-written (disko owns fileSystems) — revisit after a real scan.
- **Laptop profile** — `modules/profiles/laptop.nix`: auto-cpufreq (powersave/per-governor on battery, performance on AC) + libinput.
- **Single-disk disko** — `hosts/fern/disko.nix`: ESP 500M + 8G swap + btrfs `/root`,`/nix`. Device defaults to `/dev/sda` (SATA M.2 common on HP 15s-eq) — **if `lsblk` shows NVMe, flip the argument to `/dev/nvme0n1` in `flake/host-inventory.nix` BEFORE formatting** (disko wipes the disk).
- **SOPS**: not yet registered in `.sops.yaml`. The `hashedPassword` secret will not decrypt until the host's age key is added and `task infra:sops:update-keys` is run from a workstation holding an authorized key.

## Initial Deploy (first boot from NixOS ISO)
```bash
# 0. Verify disk ordering / type:
lsblk -o NAME,SIZE,MODEL,TRAN
# 1. Format the disk with disko (device set in flake/host-inventory.nix):
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount --flake .#fern
# 2. nixos-install --flake .#fern
# 3. Reboot, then:
cat /etc/ssh/ssh_host_ed25519_key.pub | nix shell nixpkgs#ssh-to-age -c ssh-to-age
# 4. Add the age key to .sops.yaml, then from a workstation:
task infra:sops:update-keys
# 5. Rebuild to pick up the decrypted hashedPassword
```

## Operational Interpretation
- Prefer canonical host deploy flow (`infra:deploy:host:fern`).
- No CI build enabled by default — add to Cachix workflows only if this host needs remote cache coverage.
