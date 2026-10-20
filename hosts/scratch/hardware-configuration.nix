# scratch — Fujitsu ESPRIMO D556 mini tower (i5-6500 Skylake, 128 GB f2fs SSD).
{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Skylake (i5-6500) mini tower: SATA SSD + USB via xHCI. f2fs root
  # needs the f2fs modules in the initrd (netbook pattern).
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = ["crc32" "f2fs"];
  boot.supportedFilesystems = ["f2fs"];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  # Enables DHCP on each ethernet interface. In case of scripted networking
  # (the default) this is the recommended approach.
  networking.useDHCP = lib.mkDefault true;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/6353b865-96ba-4ba9-8d2f-4f996862508e";
    fsType = "f2fs";
    options = [
      "noatime"
      "compress_algorithm=zstd"
      "compress_chksum"
      "background_gc=on"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/c0f1f0cb-501a-4ce0-a5fc-006557662a4c";
    fsType = "ext4";
  };

  # zram only — no disk swap on the shaky SSD.
  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
