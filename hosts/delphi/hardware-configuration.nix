# Hardware configuration for OCI Ampere A1 (aarch64-linux, UEFI, VirtIO).
{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_scsi"
    "virtio_net"
    "virtio_balloon"
    "virtio_blk"
    "usbhid"
  ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  # canTouchEfiVariables is false: OCI's efivarfs is often read-only, and
  # systemd-boot still writes the removable-media fallback. Why:
  # docs/delphi-install.md §"EFI without NVRAM".
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault false;
  boot.loader.systemd-boot.configurationLimit = 10;

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
