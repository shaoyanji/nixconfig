# Hardware configuration for OCI Ampere A1 (aarch64-linux, UEFI, VirtIO).
#
# NOTE: a declarative disko layout for the same disk lives in ./disko.nix,
# and it is imported into the flake alongside the disko NixOS module
# (flake/host-inventory.nix). fileSystems are owned there — do not add
# fileSystems entries here, or the two definitions collide at eval time.
# That import is also what lets nixos-anywhere partition the disk:
#   nix run github:nix-community/nixos-anywhere -- --flake .#delphi --target-host ubuntu@<ip>
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
