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

  # UEFI boot via systemd-boot.
  #
  # canTouchEfiVariables is deliberately FALSE: OCI's paravirtualized instances
  # present a firmware whose efivarfs is frequently read-only, and a bootloader
  # install that tries to write NVRAM entries aborts the install. systemd-boot
  # still drops the removable-media fallback at EFI/BOOT/BOOTAA64.EFI, which is
  # what a cloud VM boots without NVRAM. mkDefault keeps it overridable if this
  # particular tenancy turns out to have writable variables.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault false;
  boot.loader.systemd-boot.configurationLimit = 10;

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
