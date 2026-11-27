# zeno — Low-resource NAT VPS in Dallas (x86_64 KVM, BIOS, 961 MiB RAM, 35 GiB ext4).
# Stage 1 base landing: SOPS/age secrets, authorized keys, Tailscale, zram + 2 GiB swapfile,
# and WAN binary cache substitution (Cachix + Cloudflare R2) with zero local builds.
{
  self,
  lib,
  ...
}: {
  imports = [
    self.modules."profiles.base-node"
    ./hardware-configuration.nix
  ];

  system.stateVersion = "24.11";
  networking.hostName = "zeno";

  # BIOS/MBR boot via GRUB on /dev/vda; base-node's boot.nix defaults to systemd-boot + EFI.
  profiles.boot = {
    systemd-boot = false;
    efi = false;
  };
  boot.loader.grub = {
    enable = true;
    efiSupport = false;
  };

  # Static NAT IPv4 from provider netplan (dhcp4 is disabled on enp16s0).
  networking.useDHCP = false;
  networking.networkmanager.unmanaged = ["enp16s0"];
  networking.interfaces.enp16s0.ipv4.addresses = [
    {
      address = "192.168.122.36";
      prefixLength = 24;
    }
  ];
  networking.defaultGateway = "192.168.122.1";
  networking.nameservers = ["1.1.1.1" "8.8.4.4"];

  boot.tmp.cleanOnBoot = true;
  boot.supportedFilesystems = ["ext4"];

  # Never compile on 961 MiB RAM; always substitute from Cachix / Cloudflare R2 / upstream.
  nix.settings = {
    max-jobs = 0;
    cores = 1;
  };

  nix.gc.options = lib.mkForce "--delete-older-than 7d";

  # 1 GB RAM OOM protection: 100% zram (zstd, priority 100 from base-node) + 2 GiB ext4 swapfile.
  zramSwap.memoryPercent = lib.mkForce 100;
  swapDevices = [
    {
      device = "/swapfile";
      size = 2048;
    }
  ];

  # Keep the system closure minimal on ~30 GiB disk.
  documentation = {
    enable = false;
    nixos.enable = false;
    man.enable = false;
    doc.enable = false;
  };

  services.tailscale.enable = true;
  networking.firewall.trustedInterfaces = ["tailscale0"];
}
