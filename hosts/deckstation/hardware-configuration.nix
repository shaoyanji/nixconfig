# GENERATED PLACEHOLDER — must be replaced by `nixos-generate-config` on
# the target machine before the first build of the deckstation host.
#
# On the target (live ISO or staged chroot):
#   sudo nixos-generate-config --root /mnt
#   cp /mnt/etc/nixos/hardware-configuration.nix \
#      /path/to/this/repo/hosts/deckstation/hardware-configuration.nix
#
# Adjust the kernel modules, fileSystems, and swapDevices entries for
# the real hardware. The defaults below are empty so a missing
# placeholder makes the failure obvious at evaluation time.
{ config, lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];  # Replace with target `lspci -k` output.
  boot.initrd.availableKernelModules = [];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  # Evaluation-time placeholder so the flake checks cleanly. REPLACE
  # device + fsType with the actual `blkid` output (and run
  # `nixos-generate-config` on the target) before deploying.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}
