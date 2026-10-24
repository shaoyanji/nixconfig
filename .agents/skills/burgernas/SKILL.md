---
name: burgernas
description: "BurgerNAS (Synology DS220j cold vault): WoL power, restic backup target, leech-only Transmission."
version: 0.1.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['burgernas', 'synology', 'dsm', 'cold-vault', 'restic', 'wol', 'transmission']
    related_skills: ['infra', 'data']
---

# burgernas — DS220j Cold Vault Control Plane

Operate BurgerNAS, the fleet's secondary cold backup vault and storage extension
(a Synology DiskStation **DS220j**, DSM 7.4.1, aarch64, **512 MiB RAM**).

- **Host**: `192.168.3.92` (`eth0`), MAC `90:09:D0:06:C1:EE`
- **Tailscale**: `burgernas` / `100.72.61.23`
- **SSH alias**: `burgernas` (user `devji`)
- **Web UI**: `https://192.168.3.92:5001/`
- **restic target**: `sftp:devji@192.168.3.92:/volume1/backup/frieren/restic`
- **Credential**: NAS sudo password is read from `/run/secrets/nas` (devji). That file is
  SOPS-managed — rendered from `sops.secrets."burgernas-sudo-password"`
  (`modules/secrets.yaml`) by frieren's config; do not hand-edit it.

## Role

Cold vault: normally powered **off** (~0 W). The NAS wakes **itself** from its own
DSM power schedule at **03:25**; frieren's `restic-backups-frieren-burgernas.timer`
runs **daily at 03:28** and only *waits* for it — no magic packet is sent, and the
``wol`` task is for waking it by hand. A DSM power-off at **04:00** and frieren's
`burgernas-poweroff.timer` at **22:45** put it back to sleep. Never write
imperative cron jobs or ad-hoc scripts on the device (see its `~/AGENTS.md`).

A failed night is **silent**: the unit says so in its journal and nowhere else, and
`systemctl show -p Result` has been seen reporting `success` for a run that failed.
When the vault matters, check the snapshot list, not the unit.

**State (2026-10-14):** the frieren restic baseline seed is **complete and verified** (`ce946da9`; `restic check` clean, sampled restore matched the source), and the legacy `/volume1/Shared Library/core/Sandy` plaintext copy was removed. On-device `restic` 0.19.1 (SynoCommunity) is available for local restores, and `aria2` 1.37.0 + AriaNg 1.3.7 (RPC `:6800`, UI `/ariang/`) run alongside Transmission.

## Two tasks that run elsewhere

`burgernas:backup:seed` and `burgernas:snapshot` are `[frieren root]`: they start
and inspect the restic unit on frieren, not on the NAS. Everything else runs from
any host over the `burgernas` ssh alias.

## The aarch64 static toolbox

`tools/bin-farm/` is the single source of truth for the portable tool library on
the NAS: `farm.toml` names the tools and pins them (a release download by sha256,
or `pkgsStatic.<attr>` when upstream ships no aarch64-linux binary). Two tasks:

- `task burgernas:bin:lock` — resolves the manifest **on delphi**, the only
  aarch64 host (`~/.local/share/bin-farm`), because compiling statically is
  impossible on the NAS.
- `task burgernas:bin:deploy` — pushes `store/<sha256>/<name>` plus
  `bin/<name> -> ../store/<sha256>/<name>` to
  `/volume1/Shared Library/toolbox/`, checking each sha256 on the receiver.

Identity is content, not filename: nothing absent from `farm.toml` is touched and
a real file is never overwritten. The older flat `/volume1/Shared Library/bin-aarch64/`
collection comes from the Mac via `burgernas:bin:sync` and is *unmanaged* — do not
assume it is reproducible.

## Sharing the vault over NFS

The NAS exports `/volume1/peachcable` (tools, appimages, the archive) and DSM caps
the protocol at **NFSv4.1** — asking for `vers=4.2` fails with `Protocol not
supported`, which reads like a client problem and is not one. Frieren mounts it at
`/mnt/burgernas/peachcable`, declared in `hosts/frieren/configuration.nix` as an
automount (`systemd.automounts` + `noauto` in the fstab entry) because the NAS is
off most of the day and a boot-time mount would wait on a sleeping peer.

Adding a client is the one operation with **no CLI and no API** on DSM 7: `synoshare`
has no `--setnfspriv`, `synonfs` only manages rules for existing paths, and
`synowebapi api=SYNO.Core.Share.NFS` answers `code 102` on every version. The
export list lives in `/etc/exports`, so the imperative path is: back it up, append
the client with the same option string as its siblings, then `exportfs -ra`, and
verify with `showmount -e 127.0.0.1`. It survives until someone edits NFS
privileges in the UI; if that happens, re-add the client.

`devji`'s `~/.bashrc` puts `/volume1/Shared Library/toolbox/bin` **first** on PATH,
so the farm's sqlite3 (3.53 with FTS5) wins over the firmware's 3.40. That file is
hand-edited on the device — no nix, nothing to declare it in.

## Constraints

- **512 MiB RAM** — no compilers, browsers, containers or AI runtimes; they
  OOM-kill. Anything aarch64-static is built on delphi and only the finished
  binaries cross the wire.
- **Non-Nix** — there is no `nix`, `nixos-rebuild` or flake on the device.
- **Frieren is the backup controller** — no imperative cron or rsync on the NAS.
- **Keep WoL armed** on `eth0`, or the backup window cannot wake it.
- Power ops use devji's passwordless sudo (`/sbin/poweroff`, `/bin/ethtool`,
  `/bin/systemctl`); writing `settings.json` needs the `/run/secrets/nas` password.

## Remote `task -t`

```bash
task -t taskfiles/burgernas.yml burgernas:status
task -t taskfiles/burgernas.yml burgernas:transmission:leech
```

See also: `inventory.toml` (`[hosts.burgernas]`), `hosts/frieren/infra-stack.nix`
(restic target + `burgernas-poweroff` timer), and `docs/storage-taxonomy.md`.
