# Hardware configuration for Lenovo ThinkPad L440 (Diogenes)
{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ehci_pci"
    "ahci"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-label/diogenes-root";
    fsType = "btrfs";
    options = ["subvol=@root" "compress=zstd"];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/diogenes-root";
    fsType = "btrfs";
    options = ["subvol=@home" "compress=zstd"];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/diogenes-root";
    fsType = "btrfs";
    options = ["subvol=@nix" "noatime" "compress=zstd"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXOS-BOOT";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  services.xserver.videoDrivers = ["modesetting"];
}
