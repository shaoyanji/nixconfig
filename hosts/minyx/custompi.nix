# minyx — Raspberry Pi 3 Model B, retooled as the fleet's tunnel/jump box.
#
# 1 GiB of RAM on a USB stick with a known under-voltage history: every setting
# here is about RAM, store size and keeping the medium alive.
{
  config,
  lib,
  pkgs,
  ...
}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [
    ../../modules/config/authorized-keys.nix
    ../../modules/ssh-ca.nix
  ];

  # The old config reserved 256M of this box's 1 GiB for a VideoCore that a
  # headless jump host never shows anything on.
  boot.kernelParams = ["cma=16M"];
  boot.tmp.cleanOnBoot = true;

  # aarch64 closures are built elsewhere when they can be. This is NOT
  # `max-jobs = 0`: the host has no cached closure of its own and no push path, so
  # substitute-or-fail left it unable to even build its way back to a working
  # system. It is a WIP host pending a clean reinstall — until then the honest
  # setting is "may build, slowly", not "may never build".
  nix.settings = {
    max-jobs = 1;
    cores = 1;
    auto-optimise-store = true;
  };

  # No swap file on the stick: compressed RAM only.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # The store is the only thing that grows between fleet updates, so bound it.
  # `automatic` and `dates` are set here; the retention string belongs to
  # modules/global/global.nix (10d) — defining it in both places is a hard eval
  # error that a module-system + assertions check does not surface, because a
  # conflicting option is only detected when its value is forced.
  nix.gc = {
    automatic = true;
    dates = "weekly";
  };

  networking = {
    hostName = "minyx";
    useDHCP = true;
    # Only sshd listens. Tailscale is outbound-initiated and installs its own
    # rules, so it needs no inbound hole here.
    firewall.allowedTCPPorts = [22];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # This host is never managed in place: it takes a remotely built closure
  # pushed from delphi, and with `PermitRootLogin = "no"` plus no password for
  # its user there is no other way back in. The fleet baseline
  # (modules/profiles/base-node.nix) answers that with two settings, and this
  # host had neither: CA-signed certs are what a fleet host authenticates with,
  # and passwordless wheel sudo is what `nixos-rebuild --target-host
  # --use-remote-sudo` needs to activate the pushed system.
  ssh.ca.enable = true;
  security.sudo.wheelNeedsPassword = false;

  services.tailscale.enable = true;

  # This box had no system account at all: the old chain created only a
  # home-manager user entry, so there was nothing to log in as once HM went away.
  users.users.${user.name} = {
    isNormalUser = true;
    home = user.home;
    description = user.shortName;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = config.ssh.authorizedKeys.keys;
  };

  # ext4 is the root filesystem and vfat the firmware partition. Both are
  # declared so their tools (e2fsprogs, dosfstools) are in the closure the
  # expand-on-boot service needs, and nothing else is — no btrfs, xfs, zfs, cifs
  # or NFS tooling on a box whose only filesystem is the one it boots from.
  boot.supportedFilesystems = ["ext4" "vfat"];

  # sd-image.nix forces hardware.enableAllHardware = true, and that implies
  # enableRedistributableFirmware — which is linux-firmware at 1.98 GB, plus
  # Intel 2200/ralink/zd1211 radios, DVB tuner blobs and SOF audio DSPs. On a Pi
  # 3B the only radio is a Broadcom SDIO part, so the firmware payload drops to
  # the Pi wireless firmware and the regulatory database. The
  # all-hardware *kernel modules* stay on purpose: usb-storage/xhci in the initrd
  # is what finds this box's root disk on the USB stick.
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.wirelessRegulatoryDatabase = true;

  environment.systemPackages = with pkgs; [
    age
    curl
    gh
    gitMinimal
    jq
    mosh
    rsync
    tmux
  ];

  documentation = {
    nixos.enable = false;
    man.enable = false;
    doc.enable = false;
    info.enable = false;
    dev.enable = false;
  };

  # ── flash-write policy ──────────────────────────────────────────────────
  # Measured on the candidate stick (SanDisk Cruzer, 2026-10-26): 16.9 MB/s read
  # and `discard_max_bytes = 0` — NO TRIM at all. Without TRIM the controller
  # cannot learn which blocks the filesystem freed, so NixOS's GC churn turns into
  # rewrite-the-live-data. The response is not a tweak, it is a policy: keep bytes
  # OFF the stick.
  #
  # 1. The journal never touches it. A jump box's journal is read on the box, in
  #    the hour it happened, or it is read nowhere; `volatile` puts it in RAM and
  #    caps it there.
  # `settings`, not the removed `extraConfig`: this nixpkgs rejects the old option
  # outright, which the eval caught before anything was built.
  services.journald.settings.Journal = {
    Storage = "volatile";
    RuntimeMaxUse = "32M";
    MaxRetentionSec = "1h";
    RateLimitIntervalSec = "30s";
    RateLimitBurst = 500;
  };

  # 2. /tmp in RAM, not on the stick. No swap file on this host (zram only), so
  #    this is bounded explicitly rather than left to grow into the OOM killer.
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "128M";

  # 3. Writeback in fewer, calmer bursts. Cheap flash controllers stall under
  #    bursty traffic and the stalls land exactly during a switch.
  boot.kernel.sysctl = {
    "vm.dirty_background_ratio" = 3;
    "vm.dirty_ratio" = 8;
    "vm.dirty_writeback_centisecs" = 3000;
  };

  # 4. `fstrim` is pointless here: the device reports no discard support, so the
  #    timer would run weekly and issue requests the controller drops.
  services.fstrim.enable = false;
}
