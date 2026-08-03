# scratch — Fujitsu ESPRIMO D556 (i5-6500) Steam Remote Play client.
#
# Hardware:
#   CPU:  Intel i5-6500 (Skylake, 4c/4t)
#   GPU:  Intel HD Graphics 530 (iGPU, modesetting + Mesa)
#   RAM:  8 GB DDR4
#   SSD:  128 GB f2fs (shaky — disk IO is deliberately minimised)
#   Boot: UEFI (systemd-boot)
#
# Role:  Lightweight Steam Big Picture client — cage + steam -gamepadui
#        kiosk (greetd auto-login), mirroring ares/eisen/kellerbench.
#        NOT a Sunshine stream host: this box connects OUT to the fleet's
#        streaming rigs via Steam Remote Play (client only).
#
# Disk-IO diet (shaky f2fs SSD → "almost a ramfs"):
#   - zram 100% zstd swap, no disk swap at all
#   - /var/log, /tmp, /var/tmp, /var/cache, ~/.cache and the Steam
#     shadercache all on tmpfs (8 GB RAM budget)
#   - journald volatile (RAM only), core dumps disabled
#   - weekly fstrim + noatime + gentle writeback sysctls
{
  config,
  lib,
  pkgs,
  ...
}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/steamos.nix
  ];

  networking.hostName = "scratch";

  # /boot is ext4 (legacy BIOS + GRUB) — NOT a vfat ESP, so systemd-boot
  # cannot be used. base-node's boot.nix defaults to systemd-boot; override
  # per the machine's original layout (gist 12006e57e885fc3864e9197826d69276).
  profiles.boot = {
    systemd-boot = false;
    efi = false;
  };
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda"; # legacy BIOS MBR install — adjust if the disk is not sda
  };

  # X server is required so XWayland can host legacy X11-only windows
  # that Steam spawns inside cage's Wayland surface. No desktop
  # environment — greetd auto-logs devji into gamescope-session
  # (cage + steam -gamepadui), which is the entire user-facing UI.
  services.xserver.enable = true;

  # Intel HD 530 iGPU — Mesa via modesetting.
  hardware.graphics.enable = true;

  # Keep the repo-standard cage kiosk path from steamos.nix: the
  # upstream gamescope-session script (gamescope isn't even in the
  # closure — programs.gamescope.enable=false) is suppressed so our
  # cage wrapper wins PATH. Mirrors hosts/ares. mkForce priority 50
  # wins over steam.nix's plain assignment (priority 100).
  programs.steam.gamescopeSession.enable = lib.mkForce false;

  # ── Swap: zram only, 100% of RAM, zstd ──
  # base-node defaults to 50%; scratch has NO disk swap so we take the
  # full 8 GB (compressed ~2-4x in RAM). mkForce overrides base-node.
  zramSwap.memoryPercent = lib.mkForce 100;

  # ── Heavy-write dirs on tmpfs (8 GB RAM budget) ──
  # /tmp on tmpfs (NixOS-managed), capped at 25% of RAM.
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "25%";

  fileSystems."/var/log" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["size=128M" "mode=0755" "nosuid" "nodev"];
  };

  fileSystems."/var/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["size=256M" "mode=1777" "nosuid" "nodev"];
  };

  fileSystems."/var/cache" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["size=256M" "mode=0755" "nosuid" "nodev"];
  };

  # User + Steam caches in RAM (devji uid=1000, users gid=100).
  fileSystems."${user.home}/.cache" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["size=512M" "mode=0755" "uid=1000" "gid=100"];
  };

  # fileSystems."${user.home}/.steam/steam/steamapps/shadercache" = {
  #   device = "tmpfs";
  #   fsType = "tmpfs";
  #   options = [ "size=512M" "mode=0755" "uid=1000" "gid=100" ];
  # };

  # Journals live in RAM only — nothing hits the f2fs SSD.
  services.journald = {
    storage = "volatile";
    extraConfig = "SystemMaxUse=50M";
  };

  # No core dumps written to disk.
  systemd.coredump.enable = false;

  # Weekly TRIM for the SSD (f2fs supports discard via fstrim).
  services.fstrim.enable = true;

  # ── Writeback tuning: gentle bursts + keep metadata cached ──
  boot.kernel.sysctl = {
    "vm.swappiness" = 100; # prefer zram swap over evicting cache
    "vm.vfs_cache_pressure" = 50; # keep dentries/inodes in RAM → fewer reads
    "vm.dirty_ratio" = 10; # smaller, more frequent writeback
    "vm.dirty_background_ratio" = 5;
  };

  # Quiet early-boot console chatter.
  boot.consoleLogLevel = 3;

  # ── Nix store hygiene: small store = less SSD churn ──
  # GC is inherited from the global nix settings (modules/global/global.nix,
  # `--delete-older-than 10d`); no host-local GC override needed.
  nix.optimise.automatic = true;

  environment.systemPackages = with pkgs; [
    btop # RAM/tmpfs/zram visibility
  ];

  services.openssh.enable = true;
  system.stateVersion = "25.05";
}
