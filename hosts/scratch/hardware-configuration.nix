# scratch — Fujitsu ESPRIMO D556 mini tower (i5-6500 Skylake, 128 GB f2fs SSD).
#
# ⚠️ TODO(deploy): replace the two SCRATCH-* UUID placeholders below with the
# real values from the machine before the first deploy:
#   lsblk -f      # f2fs root UUID + vfat ESP UUID
# or:
#   blkid         # /dev/sda* partition UUIDs
{ config, lib, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # Skylake (i5-6500) mini tower: SATA SSD + USB via xHCI. f2fs root
  # needs the f2fs modules in the initrd (netbook pattern).
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ "crc32" "f2fs" ];
  boot.supportedFilesystems = [ "f2fs" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Enables DHCP on each ethernet interface. In case of scripted networking
  # (the default) this is the recommended approach.
  networking.useDHCP = lib.mkDefault true;

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/SCRATCH-F2FS-ROOT-UUID";
      fsType = "f2fs";
      options = [ "noatime" ];
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/SCRATCH-ESP-UUID";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  # zram only — no disk swap on the shaky SSD.
  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
