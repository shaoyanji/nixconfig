# scratch — Fujitsu ESPRIMO D556 (i5-6500) dwl desktop on the shared profile.
{
  lib,
  pkgs,
  ...
}: let
  user = import ../../modules/global/user.nix;
in {
  # Fork, not inheritance: see [[flake/policies.nix#desktop-fork-not-disable]].
  imports = [
    ./hardware-configuration.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/boot.nix
    ../../modules/profiles/dwl-desktop.nix
    ../../modules/profiles/nas-client.nix
  ];

  # The compositor, keybinds, launcher, bar, wallpaper and idle/lock all come from
  # the profile (modules/profiles/dwl-desktop.nix); this host only chooses which
  # of them it wants.
  profiles.dwlDesktop = {
    enable = true;
    bar.enable = true;
    greeter.enable = true;
  };

  # Replaces the fleet userland default; see [[flake/policies.nix#desktop-fork-not-disable]].
  fleet.hmUserModules = [
    ../../modules/user/base.nix
    ../../modules/user/desktop/appimage-launchers.nix
  ];

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

  services.displayManager.sddm.enable = false;

  # Reachability is infrastructure, not part of the desktop.
  services.tailscale.enable = true;

  documentation.enable = false;
  documentation.nixos.enable = false;
  documentation.man.enable = false;
  documentation.doc.enable = false;

  hardware.graphics.enable = true;

  # No disk swap; base-node's 50% default is overridden.
  zramSwap.memoryPercent = lib.mkForce 100;

  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "25%";

  fileSystems."${user.home}/.cache" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["size=512M" "mode=0755" "uid=1000" "gid=100"];
  };

  # Its own budget: appimage-run never evicts extractions (notes: appimage-run-cache-tmpfs).
  fileSystems."${user.home}/.cache/appimage-run" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["size=3G" "mode=0700" "uid=1000" "gid=100" "nosuid" "nodev"];
  };

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

  services.journald = {
    storage = "volatile";
    settings.Journal.SystemMaxUse = "50M";
  };

  systemd.coredump.enable = false;
  services.fstrim.enable = true;

  boot.kernel.sysctl = {
    "vm.swappiness" = 100; # prefer zram swap over evicting cache
    "vm.vfs_cache_pressure" = 50; # keep dentries/inodes in RAM → fewer reads
    "vm.dirty_ratio" = 10; # smaller, more frequent writeback
    "vm.dirty_background_ratio" = 5;
  };

  boot.consoleLogLevel = 3;
  nix.optimise.automatic = true;

  # The desktop's own packages come from the profile; this host adds the rest.
  environment.systemPackages = with pkgs; [
    age-plugin-tpm
    btop
    tpm2-tools
  ];

  # TPM-only recipient; base-node's sshKeyPaths would need an `&scratchhost`
  # entry that deliberately does not exist. See docs/sops-rekey.md.
  sops = {
    age.keyFile = "${user.home}/.config/sops/age/tpm-identity.txt";
    age.sshKeyPaths = lib.mkForce [];
    age.plugins = [pkgs.age-plugin-tpm];
  };

  # /dev/tpmrm0 is root:tss 0660 and --generate runs as the user.
  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };
  users.users.${user.name}.extraGroups = ["tss"];

  services.openssh.enable = true;
  system.stateVersion = "25.05";
}
