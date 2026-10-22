# scratch Exceptions

## Scope
Lightweight dwl desktop (Fujitsu ESPRIMO D556, i5-6500, 8 GB RAM, shaky 128 GB f2fs SSD).

## Key Differences
- **Desktop chain** — `globalModulesNixos` (role:heim userland) plus `base-desktop-environment.nix`, which the host keeps only for its plumbing: portals, gvfs/udisks/tumbler/upower, gnome-keyring, pipewire, `hardware.graphics`. `programs.niri.enable` and `programs.dms-greeter.enable` are force-disabled, so no niri or DMS package reaches the closure.
- **dwl** — `modules/config/dwl/config.h`, built as `pkgs.dwl.override { configH = …; }`. greetd runs `initial_session` (dwl as devji) with tuigreet as the default session, so autologin lands straight in the compositor and a logout gives a login prompt.
- **Keymap mirrors niri** — `modules/user/desktop/niri.nix` is the reference: Mod+A launcher, Mod+T terminal, Mod+Q close, Mod+H/L focus, Mod+J/K workspace, Mod+Ctrl+{H,L,J,K} move the column, Mod+1..9 / Mod+Ctrl+1..9 tags, XF86 media keys, Mod+S and Mod+Print screenshots (grim + slurp → wl-copy). `viewdir`, `viewlast`, `movestack`, `movetotag` are defined in the config because dwl has no next/previous-tag or reorder primitive.
- **No Steam** — the former Steam Remote Play kiosk role (cage + steam -gamepadui, greetd autologin) was dropped in the 2026-09 desktop conversion. Sunshine is NOT imported either.
- **No impermanence** — f2fs has no subvolume support, so the btrfs impermanence module is not used. Instead, all heavy-write dirs go on tmpfs (`/var/log`, `/var/tmp`, `/var/cache`, `~/.cache`) and zram covers 100% of RAM; journald is volatile.
- **SOPS — TPM-sealed, verified 2026-10-22, no SSH-derived recipient.** Recipient `&tpmscratch` = `age1tag1q2ng9uhpteuj830ltlf3jtanm4l2qf00xcugs82xn7k50nq04e4w24l93hw`, sealed by the Q150 firmware TPM (`/dev/tpmrm0`, group `tss`). Both planes unseal it: `/run/secrets-for-users/hashedPassword` exists, `sops-nix.service` (system) installs, and the user unit reports `Result=success` with `Environment=PATH=<age-plugin-tpm store path>`. Switch now exits **0** — the old exit-4 deploys were this host having no decryptable recipient at all. Both planes unseal through the Q150 chip: Home Manager via `modules/sops.nix` (`tpmHosts`), the system plane via `sops.age.keyFile = ~devji/.config/sops/age/tpm-identity.txt` + `plugins = [pkgs.age-plugin-tpm]` + `sshKeyPaths = mkForce []` in the host config. The recipient (`&tpmscratch`) is the only scratch entry in `.sops.yaml` on purpose — there is no `&scratch`/`&scratchhost`, so the earlier plan of registering the SSH host key (`age1r4lmxq…`) is **superseded**. Procedure and traps: `docs/sops-rekey.md` § *TPM-sealed identity*. Order: deploy `security.tpm2` + `tss` group + `age-plugin-tpm` → `sg tss -c 'age-plugin-tpm --generate -o …'` on the host → register recipient, rekey every file → point both planes at it. Until that rekey lands, `hashedPassword`, `home-manager-devji`, the user `sops-nix` unit and `vdirsyncer` fail and `switch-to-configuration` exits 4 even though the system activates.
- **Audio** — the onboard HDA controller was disabled in firmware (no `00:1f.3`, no card, `snd_hda_intel` bound to nothing). Enabling it in the BIOS setup was the whole fix: `00:1f.3` now enumerates and PipeWire exposes `Built-in Audio Analog Stereo`. No config change was involved, and none should be added.
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
