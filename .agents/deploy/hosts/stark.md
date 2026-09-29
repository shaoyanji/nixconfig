# stark Exceptions

## Scope
Dell Inspiron 24 3477 All-in-One (i5-7200U Kaby Lake-U, HD 620 + MX110 Optimus, 16 GB RAM) — Steam Big Picture desktop (eisen-style, persistent, no impermanence).

## Key Differences
- **Desktop chain** — `globalModulesNixos` (niri + DankMaterialShell greeter + role:heim userland) via `base-desktop-environment.nix`. `autoLogin` as devji into `steam` (upstream gamescope-session); DMS greeter is the fallback after the session exits.
- **Steam + gamescope** — `modules/profiles/steam.nix` (programs.steam + gamescopeSession) and `programs.gamescope.enable = true`, eisen-style. NOT the noDE steamos.nix kiosk path (ares).
- **MX110 = Pascal (sm_61)** — `nvidiaPackages.legacy_580` (final series for Pascal), `open = false`, persistenced disabled (nixpkgs bug), same as ares/kellerbench. `cudaSupport` stays OFF (nothing needs it; avoids source builds).
- **Muxless Optimus** — panel is wired to the HD 620; PRIME **render offload** with `enableOffloadCmd` (`nvidia-offload %command%` in Steam launch options). Bus IDs: Intel `PCI:0:2:0`, MX110 `PCI:1:0:0` — verify with `lspci -nn | grep -Ei 'vga|3d'` on first boot.
- **Dual-disk disko** — `hosts/stark/disko.nix`: SSD `/dev/sdb` (ESP + 8G swap + btrfs /root,/nix; the kernel enumerates the HDD first) + 1 TB HDD `/dev/sda` (btrfs `-L steam` → `/mnt/steam`). **disko wipes BOTH disks** — check `lsblk` before running it. Devices are set in `flake/host-inventory.nix`.
- **SOPS**: not yet registered in `.sops.yaml`. The `hashedPassword` secret will not decrypt until the host's age key is added and `task infra:sops:update-keys` is run from a workstation holding an authorized key.
- **hardware-configuration.nix is hand-written** (disko owns fileSystems); revisit the initrd module list after a real `nixos-generate-config` scan on the metal.

## Initial Deploy (first boot from NixOS ISO)
```bash
# 0. Verify disk ordering: SSD (SK hynix SC311) must be /dev/sdb, 1 TB
#    HDD /dev/sda. If lsblk disagrees, adjust the devices in
#    flake/host-inventory.nix BEFORE formatting.
lsblk -o NAME,SIZE,MODEL,SERIAL
# 1. Format both disks with disko:
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount --flake .#stark
#    (or: nix build .#nixosConfigurations.stark.config.system.build.diskoScript)
# 2. nixos-install --flake .#stark
# 3. Reboot, then:
cat /etc/ssh/ssh_host_ed25519_key.pub | nix shell nixpkgs#ssh-to-age -c ssh-to-age
# 4. Add the age key to .sops.yaml, then from a workstation:
task infra:sops:update-keys
# 5. Rebuild to pick up the decrypted hashedPassword
# 6. Own the Steam library once, then add it in Steam:
sudo chown devji:users /mnt/steam
```

## Operational Interpretation
- Prefer canonical host deploy flow (`infra:deploy:host:stark`).
- No CI build enabled by default — add to Cachix workflows only if this host needs remote cache coverage.
