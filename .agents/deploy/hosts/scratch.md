# scratch Exceptions

## Scope
Steam Remote Play client (Fujitsu ESPRIMO D556, i5-6500, 8 GB RAM, shaky 128 GB f2fs SSD).

## Key Differences
- **No impermanence** — f2fs has no subvolume support, so the btrfs impermanence module is not used. Instead, all heavy-write dirs go on tmpfs (`/var/log`, `/var/tmp`, `/var/cache`, `~/.cache`, shadercache) and zram covers 100% of RAM.
- **SOPS**: not yet registered in `.sops.yaml`. The `hashedPassword` secret will not decrypt until the host's age key is added and `task infra:sops:update-keys` is run from a workstation holding an authorized key.
- **Steam Remote Play client only** — Sunshine is NOT imported. This box connects out to the fleet's streaming rigs.
- **Storage UUIDs (filled)**: from the original machine config (gist `12006e57e885fc3864e9197826d69276`) — root = f2fs `6353b865-96ba-4ba9-8d2f-4f996862508e`, /boot = ext4 `c0f1f0cb-501a-4ce0-a5fc-006557662a4c`.
- **Boot**: /boot is **ext4** → legacy BIOS + GRUB. `systemd-boot` is disabled (base-node default overridden in `hosts/scratch/configuration.nix`) and GRUB installs to the `/dev/sda` MBR. Adjust the GRUB device if the disk is not sda.
- **GC**: no host-local `nix.gc` — inherits the global `--delete-older-than 10d` from `modules/global/global.nix`.

## Initial Deploy (first boot from NixOS ISO)
```bash
# 1. Partition manually (f2fs root + vfat ESP), or use disko (not yet written)
# 2. nixos-install --flake .#scratch
# 3. Reboot, then:
#    cat /etc/ssh/ssh_host_ed25519_key.pub | nix shell nixpkgs#ssh-to-age -c ssh-to-age
# 4. Add the age key to .sops.yaml, then from a workstation:
#    task infra:sops:update-keys
# 5. Rebuild to pick up the decrypted hashedPassword
```

## Operational Interpretation
- Prefer canonical host deploy flow (`infra:deploy:host:scratch`).
- No CI build enabled by default — too small/light to justify CI minutes.