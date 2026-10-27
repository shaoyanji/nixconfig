# minyx — Pi 3B jump box, pushed to the device from delphi

Deployment is a **closure push**, not a flash. The host is built on delphi (the
fleet's only aarch64 builder) and activated over ssh on the running system; no
sdImage is built for it any more. The device's own FAT partition already boots
U-Boot, which reads `/boot/extlinux/extlinux.conf` from the root filesystem — the
file a switch writes. This host is not on `infra:deploy` or the sweeps (inventory
`status = "preserved"`), so the commands below are the deploy path.

## Push topology — the canonical deploy

```bash
# on delphi, from the checkout, as devji — NOT sudo
cd ~/Documents/nixconfig
nixos-rebuild switch -L --builders "" --flake .#minyx \
  --target-host devji@192.168.3.3 --use-remote-sudo
```

- **`devji`, not `sudo`.** root cannot evaluate a devji-owned git tree (`repository
  path is not owned by current user`, which root's `safe.directory` does not
  suppress), and only the activation needs privilege on the target —
  `--use-remote-sudo` supplies it there. `root@` is not a target either:
  `PermitRootLogin = "no"`, and `ssh.ca.enable` + passwordless wheel sudo (the
  two settings this host lacked) are what leave a way back in.
- **Reachable without a tailnet on the Pi:** frieren advertises `192.168.3.0/24`
  and delphi runs `--accept-routes=true`, so the cloud host opens TCP/22 to a LAN
  address.
- **The build is native and cheap, unlike the image.** Delphi and minyx are both
  aarch64, so nothing is emulated; the RPi kernel and modules substitute from
  `shaoyanji.cachix.org` (155 MiB) and ~26 derivations compile in about five
  minutes. `--builders ""` keeps a routine push off nixbuild.net. Once built, the
  switch is a closure copy plus activation — measured 19.7 s in
  `switch-to-configuration` on 2026-10-27.
- **Nothing goes through frieren or harmonia.** The copy is delphi → minyx over the
  LAN route. Harmonia is an x86 store: an aarch64 closure parked there is dead
  weight that `nix store optimise` would then churn for no benefit.
- **`infra:deploy`/`infra:apply` do not reach this host.** Inventory says
  `status = "preserved"` (warn + exit 0), and `activate-host.sh` pulls from
  harmonia — the wrong arch path. The push above *is* the deploy.
- **Exception: after `nix flake update`.** A nixpkgs bump turns most of the aarch64
  closure into new derivations, which 2 OCPU / 11 GiB cannot absorb on its own.
  Attach remote builders for that one push (nixbuild.net — budgeted, 25
  build-hours/month) instead of letting delphi grind, then push as usual. Routine
  config changes never need them.
- **Rollback is a reflash.** The previous generation stays on the card
  (`nixos-1-default` in `/boot/extlinux/extlinux.conf`, kernel in `/boot/nixos`),
  but the board is headless: choosing it needs a serial console.

## DNS failover role (declared 2026-10-27; `status = "active"`)

This board is the **DNS failover** for frieren's Pi-hole: blocky answers the
`*.frieren.lan` zone from local records, and keepalived holds `192.168.3.50` at
priority 1 — it can never preempt a healthy frieren (200), and claims the address
when frieren's resolver stops answering the zone. Peers are unicast
(`192.168.3.25` here, the reserved address of the role's link there): multicast VRRP
split brain on this LAN is
what put one address on two MACs on 2026-10-27.

Do not push this role until all four are true. The first attempt skipped them and
took the LAN down:

| Precondition | Why | Check |
| :--- | :--- | :--- |
| **5 V/2.5 A supply** | `vcgencmd get_throttled = 0x50000` on the interim boot: under-voltage and throttling have happened. A failover that browns out is worse than none | `vcgencmd get_throttled` on the board |
| **the role link reserved** | `unicastPeers` on frieren hardcodes this address, so a new lease silently points the group at nothing. Reservations are **per MAC** and this board has two (wifi + USB ethernet), so reserving one link does not cover the other | router admin page |
| **`.50` outside the pool** | the VIP has no MAC to reserve, so only the pool's bounds protect it. `.53` failed exactly here: the router was already leasing it to this board | `task checks:dns:pool POOL=<start>-<end>` → exit 0 |
| **clean install on the card** | the preserved note's condition: the current boot is an interim one | `nixos-version`, `/boot/extlinux/extlinux.conf` |

Then the push (from delphi, aarch64 → aarch64, no emulation):

```bash
nixos-rebuild switch -L --builders "" --flake .#minyx \
  --target-host devji@192.168.3.3 --use-remote-sudo
```

Verify on the board, in this order — both units fail quietly with a green config:

```bash
systemctl is-active blocky keepalived                      # both active
ip -br addr | grep -v lo                                   # wlan0 UP: the role's link, not enu1u1
journalctl -u keepalived -b | grep -iE 'track script|state'  # must NOT say "track script dns not found"
ip -br addr show wlan0                                     # no .50 while frieren is healthy
dig +short @127.0.0.1 photos.frieren.lan                    # 192.168.3.25
```

A rejected track script is the silent failure: keepalived then holds the VIP with no
health check, so it looks healthy while the resolver behind it is dead. Then run the
two-direction takeover in [`docs/dns-failover.md`](../../../docs/dns-failover.md)
("The failover test"); until the address has moved out *and* back, the group is
unproven.

Known gap, by backend design: blocky has no dnsmasq-style conditional forward, so
`*.cloudforest-kardashev.ts.net` and `gok` do **not** resolve on it. The LAN zone and
the static `eisen.lan` / `laya.lan` / `tts.lan` records do. Do not "fix" this by
pointing blocky at frieren — a failover that needs the primary is not one.

## Label declaration must match the media (the brick of 2026-10-26)

`fileSystems."/"` is generated from `sdImage.rootVolumeLabel`, so the pushed
system's stage-1 mounts `/dev/disk/by-label/<that string>`. The flashed media
carried the stock image's `NIXOS_SD` while the tree declared `NIXER`; the next
reboot panicked in stage-1 and the host had no network to fix itself. Two things
made it recoverable: the closure and boot entries were already on the card, and a
stock `nixos`/`nixos` console login still worked.

Before any push to this host, compare the declared label with the target's:

```bash
nix eval --raw .#nixosConfigurations.minyx.config.sdImage.rootVolumeLabel
ssh devji@192.168.3.9 'sudo blkid -p /dev/sda2 | grep -o "LABEL=\"[^\"]*\""'
```

The declaration now matches the flashed media (`NIXOS_SD`), so relabelling the
stick is not part of this workflow. `sudo e2label /dev/sda2 <label>` is the online
fix if the two ever diverge again.

## Verified state (2026-10-27, after a reboot that came back unattended)

- **sops is enrolled and decrypting.** `custompi.nix` declares `defaultSopsFile`,
  `age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"]` and the `github-token`
  secret (`key = "ghsudo"`, owner `devji`). The host's own tooling names the
  identity it derived — *Imported /etc/ssh/ssh_host_ed25519_key as age key with
  fingerprint age155uxts5…* — which is `&minyxhost` in both `.sops.yaml` files.
  `/run/secrets/github-token` renders `0400 devji` and `gh auth status` with it
  reports account `shaoyanji`, so `ghcs` works.
- **Push as `devji`, not as root.** Under `sudo` the store copy authenticates as
  root, whose key holds no cert for `devji` — observed as `devji@192.168.3.9:
  Permission denied (publickey,keyboard-interactive)` after a successful build.
  devji's `~/.ssh` on delphi carries the CA cert; `--use-remote-sudo` elevates on
  the target only.
- **Tailscale is still logged out** — the one piece not done. It needs a tailnet
  auth key (a sops slot + `services.tailscale.authKeyFile`, or a one-off
  `sudo tailscale up --authkey=…`, which survives reboot: `/var/lib/tailscale` is
  on the card and this host has no impermanence).
- **Disk after GC: 2.2 GB of 15 GB** (`nix-env --delete-generations old` +
  `nix-collect-garbage -d` freed 752 paths / 2.3 GiB; the stock generation and the
  superseded initrd are gone, and `switch-to-configuration boot` pruned
  `/boot/nixos`).
- **Wireless is declarative** (`custompi.nix`): NetworkManager with
  `ensureProfiles.environmentFiles` pointed at the sops template that renders the
  fleet SSID and PSK — the same `gokrazy/gok/wifi_ssid` and `wifi_psk` entries the
  gok appliance uses. Verified on the box: `wlan0` connected to the sops SSID with a
  DHCP lease, ethernet still the preferred path, and the store copy of the profile
  holding only `psk=$WIFI_PSK` while
  `/run/NetworkManager/system-connections/fleet-wifi.nmconnection` holds the
  substituted value. `useDHCP` is *not* set: the NetworkManager module assigns it
  `false` outright, and two definitions of one option is a hard eval error.
- **sops-nix key paths are slash-separated.** `key = "gokrazy.gok.wifi_psk"`
  fails the build-time manifest check ("the key … cannot be found") because
  `pkgs/sops-install-secrets/main.go` splits the path on `/`; the dotted form
  belongs to `gok.sh`, which parses the same entry its own way. A dotted key is
  looked up as one literal name, and the failure only appears when the derivation
  is built — the eval gate cannot see it.

- **Every client terminal works, and none of them is pinned.** kitty / foot /
  alacritty reach this box as three different `TERM`s, so `custompi.nix` sets
  `environment.enableAllTerminfo = true` instead of base-node's
  `TERM=xterm-256color`. Verified after the 2026-10-27 push: `xterm-kitty`,
  `foot`, `alacritty` and `ghostty` entries present under
  `/run/current-system/sw/share/terminfo`, `infocmp xterm-kitty` resolves, and
  `tmux new -d` starts under each. Cost: 11 store paths, 65 KB.
- **Channels are gone, not just disabled.** The stock image's
  `/root/.nix-defexpr/channels` and `/nix/var/nix/profiles/per-user/root/channels`
  made every activation warn (NixOS/nix#9574: Nix may still read them when
  `NIX_PATH` is unset). `systemd.tmpfiles.rules` in `custompi.nix` removes both,
  plus the `channels-N-link` generations, so a reflash and re-push cannot bring a
  second nixpkgs back.

## Image layout (the flash path, retired)

Kept because it is the ownership map for anyone who goes back to flashing. It

`hosts/minyx/hardware-configuration.nix` imports the **generic**
`installer/sd-card/sd-image.nix`, not `sd-image-aarch64.nix`. The aarch64
wrapper also imports `nixos/modules/profiles/base.nix` — the minimal
installation CD's package list — which cost 70 MB of direct packages (vim alone
46 MB) plus samba via `cifs-utils`, and nine filesystem types.

Ownership of the two halves:

- FAT firmware partition: nixos-hardware's `raspberry-pi` module, which sets
  `sdImage.populateFirmwareCommands` with `mkForce`. A firmware block written in
  the host file is dead code.
- `/boot` on the root partition: the host file, via
  `sdImage.populateRootCommands` and extlinux. That is the piece
  `sd-image-aarch64.nix` used to supply, and the one thing to suspect first if
  the image does not boot.

`sd-image.nix` also forces `hardware.enableAllHardware = true`, which implies
`enableRedistributableFirmware`: `linux-firmware` at 1.98 GB for a board with one
Broadcom SDIO radio. `custompi.nix` forces it off and keeps the all-hardware
kernel modules, which the initrd needs to find a root disk on USB.

## Measured

Same-basis cache walk (systemPackages + kernel, narinfo over HTTPS, no build):

```
with profiles/base   344 paths  1.31 GB
without              240 paths  0.85 GB      systemPackages 166 → 133
```

- `vim` 46 MB, removed with the profile; `programs.nano.enable` defaults true,
  so an editor remains.
- `python3` 147 MB was transitive — `git` was the largest referrer — and
  `gitMinimal` (34 paths / 0.19 GB) drops it.
- `helix` is 297 MB on aarch64 against vim's 46 MB. Adding it is one line in
  `custompi.nix` and a quarter of the image.
- `binutils` is absent, so there is no `ld`: `pip install` of anything with C
  extensions cannot build on the box.

## Traps

- **The eval gate does not force option values.** `checks:host HOST=minyx
  MODE=eval` passes on a config with a duplicate option definition (it caught
  nothing when `nix.gc.options` was defined in both `custompi.nix` and
  `modules/global/global.nix`), because a conflict is only detected when the
  value is read. A build, or a forced toplevel, is the only proof.
- The host had no system account before this work — only a Home Manager user
  entry — so a preserved config was never loginable.
- Anything that authenticates the host still has to be added deliberately: the
  Tailscale auth key and the `github-token` `ghcs` reads are declared by no
  module, and `.sops.yaml` has no minyx recipient, so a rekey is part of the fix.
- **Resolve the device's own address before the reboot, not after.** hostname is
  served by DHCP on `192.168.3.9`; a switch does not change the kernel hostname
  (`hostname` still printed `nixos` while `/etc/hostname` said `minyx`).
