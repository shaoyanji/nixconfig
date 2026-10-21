# scratch Exceptions

## Scope
Lightweight dwl desktop (Fujitsu ESPRIMO D556, i5-6500, 8 GB RAM, shaky 128 GB f2fs SSD).

## Key Differences
- **Desktop chain** — `globalModulesNixos` (role:heim userland) plus `base-desktop-environment.nix`, which the host keeps only for its plumbing: portals, gvfs/udisks/tumbler/upower, gnome-keyring, pipewire, `hardware.graphics`. `programs.niri.enable` and `programs.dms-greeter.enable` are force-disabled, so no niri or DMS package reaches the closure.
- **dwl** — `modules/config/dwl/config.h`, built as `pkgs.dwl.override { configH = …; }`. greetd runs `initial_session` (dwl as devji) with tuigreet as the default session, so autologin lands straight in the compositor and a logout gives a login prompt.
- **Keymap mirrors niri** — `modules/user/desktop/niri.nix` is the reference: Mod+A launcher, Mod+T terminal, Mod+Q close, Mod+H/L focus, Mod+J/K workspace, Mod+Ctrl+{H,L,J,K} move the column, Mod+1..9 / Mod+Ctrl+1..9 tags, XF86 media keys, Mod+S and Mod+Print screenshots (grim + slurp → wl-copy). `viewdir`, `viewlast`, `movestack`, `movetotag` are defined in the config because dwl has no next/previous-tag or reorder primitive.
- **No Steam** — the former Steam Remote Play kiosk role (cage + steam -gamepadui, greetd autologin) was dropped in the 2026-09 desktop conversion. Sunshine is NOT imported either.
- **No impermanence** — f2fs has no subvolume support, so the btrfs impermanence module is not used. Instead, all heavy-write dirs go on tmpfs (`/var/log`, `/var/tmp`, `/var/cache`, `~/.cache`) and zram covers 100% of RAM; journald is volatile.
- **SOPS**: not yet registered in `.sops.yaml`, so activation cannot decrypt: `hashedPassword` is missing and `home-manager-devji` fails on the user `sops-nix` unit (which also takes `vdirsyncer` with it). Everything else activates. Fix is: add `age1r4lmxq9027uvl58u7kfqw40epmtzefklpt5d9q9ldsvhzzcmgf9s76xz2d` to `.sops.yaml`, run `task infra:sops:update-keys` from a workstation holding an authorized key, then redeploy.
- **No audio hardware in PCI space** — verified 2026-10-22: `lspci` lists 11 devices and no function at `00:1f.3`, `/proc/asound/cards` is empty, and `snd_hda_intel` loads with zero devices, so PipeWire (healthy: pipewire, pipewire-pulse and wireplumber all active) has no sink. Nothing in the config can fix this — the onboard HDA controller is disabled in firmware. Enable onboard audio in the BIOS setup (F2), save, reboot; the controller appears at `00:1f.3` and PipeWire picks it up with no config change.
- **Storage UUIDs (filled)**: from the original machine config (gist `12006e57e885fc3864e9197826d69276`) — root = f2fs `6353b865-96ba-4ba9-8d2f-4f996862508e`, /boot = ext4 `c0f1f0cb-501a-4ce0-a5fc-006557662a4c`.
- **Boot**: /boot is **ext4** → legacy BIOS + GRUB. `systemd-boot` is disabled (base-node default overridden in `hosts/scratch/configuration.nix`) and GRUB installs to the `/dev/sda` MBR. Adjust the GRUB device if the disk is not sda.
- **GC**: no host-local `nix.gc` — inherits the global `--delete-older-than 10d` from `modules/global/global.nix`.

## Initial Deploy (first boot from NixOS ISO)
```bash
# 1. Partition manually (f2fs root + ext4 /boot), or use disko (not yet written)
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
