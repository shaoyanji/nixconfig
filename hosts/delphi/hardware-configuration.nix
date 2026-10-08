# Hardware configuration for OCI Ampere A1 (aarch64-linux, UEFI, VirtIO).
#
# NOTE: a declarative disko layout for the same disk lives in ./disko.nix —
# it is intentionally NOT imported here so the runtime fileSystems below
# stay authoritative. Use it with nixos-anywhere when reprovisioning:
#   nix run github:nix-community/nixos-anywhere -- \
#     --flake .#delphi --disko hosts/delphi/disko.nix <target>
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

  # UEFI boot via systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10;

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    options = ["noatime"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
