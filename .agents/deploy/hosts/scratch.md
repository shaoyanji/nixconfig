# scratch Exceptions

## Scope
Lightweight dwl desktop (Fujitsu ESPRIMO D556, i5-6500, 8 GB RAM, shaky 128 GB f2fs SSD).

## Key Differences
- **Desktop chain** — `globalModulesNixos` (role:heim userland) plus `base-node.nix`, `boot.nix` and **`profiles.dwlDesktop`** (`modules/profiles/dwl-desktop.nix`) — the same profile netbook adopts, so the desktop is one module with per-host switches rather than two drifted copies. The profile owns the compositor, session wrapper, launcher, bar, wallpaper, idle/lock, portals, pipewire, upower, appimage, the nerd font and greetd; this host keeps only its boot layout, NAS client and userland. `base-desktop-environment.nix` is **not** imported: it carries niri, DMS and the KDE/GNOME portal stack, and `programs.niri.enable` / `programs.dms-greeter.enable` are asserted off by the fork rule.
- **dwl** — `modules/config/dwl/config.h`, built by the profile as `pkgs.dwl.override { configH = …; }`; the keymap is no longer host-local. greetd runs `initial_session` (dwl as devji) with tuigreet as the default session (`profiles.dwlDesktop.greeter.enable = true`), so autologin lands straight in the compositor and a logout gives a login prompt.
- **Launcher, bar, lock** — Mod+A and Mod+Space run `fleet-menu` (`modules/scripts/fleet-menu.sh`): XDG desktop entries *and* `$PATH` binaries in one menu. It replaces the `j4-dmenu-desktop --dmenu=wmenu …` pair, which each listed only half the launchers and made a dmenu-shaped command line (`Exec` cannot survive a dmenu round-trip on one line). waybar reads `/etc/xdg/waybar/`, which is what lets this host — no Home Manager — share a bar with netbook; swayidle locks with `waylock` after 10 min and before sleep.
- **No file manager, and no gvfs** — `nautilus`, `gvfs`, `udisks2`, `tumbler` and `gnome-keyring` are all absent (read off the built config, not off this page). `59db6a55` dropped `base-desktop-environment.nix` when it forked the desktop, and that module was the only thing providing them; an earlier version of this page claimed the host still had them. `xdg-desktop-portal-gtk` is present and `xdg.portal.config.common.default = ["gtk"]`, so file choosers still work — there is just no file manager, no trash, no thumbnails and no secret-service client behind them.
- **Keymap mirrors niri** — `modules/user/desktop/niri.nix` is the reference: Mod+A launcher, Mod+T terminal, Mod+Q close, Mod+H/L focus, Mod+J/K workspace, Mod+Ctrl+{H,L,J,K} move the column, Mod+1..9 / Mod+Ctrl+1..9 tags, XF86 media keys, Mod+S and Mod+Print screenshots (grim + slurp → wl-copy). `viewdir`, `viewlast`, `movestack`, `movetotag` are defined in the config because dwl has no next/previous-tag or reorder primitive.
- **No Steam** — the former Steam Remote Play kiosk role (cage + steam -gamepadui, greetd autologin) was dropped in the 2026-09 desktop conversion. Sunshine is NOT imported either.
- **No impermanence** — f2fs has no subvolume support, so the btrfs impermanence module is not used. Instead, all heavy-write dirs go on tmpfs (`/var/log`, `/var/tmp`, `/var/cache`, `~/.cache`) and zram covers 100% of RAM; journald is volatile.
- **SOPS — TPM-sealed, verified 2026-10-22, no SSH-derived recipient.** Recipient `&tpmscratch` = `age1tag1q2ng9uhpteuj830ltlf3jtanm4l2qf00xcugs82xn7k50nq04e4w24l93hw`, sealed by the Q150 firmware TPM (`/dev/tpmrm0`, group `tss`). Both planes unseal it: `/run/secrets-for-users/hashedPassword` exists, `sops-nix.service` (system) installs, and the user unit reports `Result=success` with `Environment=PATH=<age-plugin-tpm store path>`. Switch now exits **0** — the old exit-4 deploys were this host having no decryptable recipient at all. Both planes unseal through the Q150 chip: Home Manager via `modules/sops.nix` (`tpmHosts`), the system plane via `sops.age.keyFile = ~devji/.config/sops/age/tpm-identity.txt` + `plugins = [pkgs.age-plugin-tpm]` + `sshKeyPaths = mkForce []` in the host config. The recipient (`&tpmscratch`) is the only scratch entry in `.sops.yaml` on purpose — there is no `&scratch`/`&scratchhost`, so the earlier plan of registering the SSH host key (`age1r4lmxq…`) is **superseded**. Procedure and traps: `docs/sops-rekey.md` § *TPM-sealed identity*. Order: deploy `security.tpm2` + `tss` group + `age-plugin-tpm` → `sg tss -c 'age-plugin-tpm --generate -o …'` on the host → register recipient, rekey every file → point both planes at it. Until that rekey lands, `hashedPassword`, `home-manager-devji`, the user `sops-nix` unit and `vdirsyncer` fail and `switch-to-configuration` exits 4 even though the system activates.
- **Audio** — the onboard HDA controller was disabled in firmware (no `00:1f.3`, no card, `snd_hda_intel` bound to nothing). Enabling it in the BIOS setup was the whole fix: `00:1f.3` now enumerates and PipeWire exposes `Built-in Audio Analog Stereo`. No config change was involved, and none should be added.
- **Storage UUIDs (filled)**: from the original machine config (gist `12006e57e885fc3864e9197826d69276`) — root = f2fs `6353b865-96ba-4ba9-8d2f-4f996862508e`, /boot = ext4 `c0f1f0cb-501a-4ce0-a5fc-006557662a4c`.
- **Boot**: /boot is **ext4** → legacy BIOS + GRUB. `systemd-boot` is disabled (base-node default overridden in `hosts/scratch/configuration.nix`) and GRUB installs to the `/dev/sda` MBR. Adjust the GRUB device if the disk is not sda.
- **GC**: no host-local `nix.gc` — inherits the global `--delete-older-than 10d` from `modules/global/global.nix`.
- **Stale software key**: `~/.config/sops/age/keys.txt` (189 B, Aug 3) survives from the pre-TPM install. Its public half `age12p7hss…` is **not** a recipient of any current file, so it decrypts nothing — but it is exportable key material on a host whose point is that nothing exportable exists. Delete it once the TPM path is proven.

## Two checkouts — read this before "pulling" here

`~/Documents/nixconfig` on this host is **not a repository**: it is a symlink into
`…-home-manager-files/Documents/nixconfig` → `…-hm_nixconfig`, the read-only copy of
whatever generation is active. `git rev-parse HEAD` there reports the *generation's*
commit and looks reassuring; `git pull` cannot work. The clone is `~/nixconfig`, and
on 2026-10-22 it was **2768 commits behind** (Aug 3 `5a4a2be`) with an uninitialised
`modules/secrets` — every "is the host current?" check against the `$HOME` path was
reading the store copy and answering about the wrong tree.

```bash
cd ~/nixconfig
git fetch origin && git status -sb          # ahead/behind before touching anything
# `submodule.recurse true` is set in this clone's config, so a plain `git pull`
# fetches modules/secrets and ABORTS the whole pull on this host (exit 1).
git -c submodule.recurse=false -c fetch.recurseSubmodules=false \
  pull --ff-only --no-recurse-submodules origin main
git submodule status                        # expect " 7a35ad4…" (space = clean)
git ls-tree HEAD modules/secrets            # gitlink must equal the worktree HEAD
```

Local edits on this host are not necessarily upstream: the 2026-10-22 clone had a
hand-edited `hosts/scratch/configuration.nix` (the old Steam-kiosk variant) and two
untracked `*.original.nix`. Back them up outside the tree before restoring, or
`--ff-only` refuses to run over them.

**The submodule cannot be fetched on this host.** `modules/secrets` is private
(`git@github.com:shaoyanji/secrets.git`) and scratch has no GitHub credentials
(`ssh -T git@github.com` → *Host key verification failed*; `~/.ssh` holds only
`codespaces.auto`). `git submodule update --init` fails with *Could not read from
remote repository*. Bring the exact commit over from a host that already has it:

```bash
# on frieren (submodule clean at the gitlink the pull expects)
cd ~/Documents/nixconfig/modules/secrets && git bundle create /tmp/secrets.bundle --all
cat /tmp/secrets.bundle | ssh devji@100.97.17.113 'cat > /tmp/secrets.bundle'

# on scratch
cd ~/nixconfig && rm -rf modules/secrets
git clone -q /tmp/secrets.bundle modules/secrets
git -C modules/secrets remote set-url origin git@github.com:shaoyanji/secrets.git
git submodule status        # no leading '-' ; tree hash must equal frieren's
```

Verify by content, not by the checkout's self-report: the submodule `HEAD` and
`HEAD^{tree}` must equal frieren's, `.sops.yaml` md5 must equal the root copy, and
the mirror must match (`scripts/task/sops-drift-check.sh`, 7 files, 36 recipients).

Also: **`~/Taskfile.yml` does not exist on this host**, so the tautological task
plane described in `AGENTS.md` is not present here — `task` must be run from
`~/nixconfig`.

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
- CI **is** enabled (the compiled registry's `ci` defaults to true and this host carries no `ci = false`): `task dev:ci:trigger:scratch` builds `nixosConfigurations.scratch` and `hostChecks.x86_64-linux.scratch` and pushes them to cachix, which is how a closure this host must not compile locally gets warmed.
