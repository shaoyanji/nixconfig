# GENERATED PLACEHOLDER — must be replaced by `nixos-generate-config` on
{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Replace with target `lspci -k` output.
  boot.initrd.availableKernelModules = [];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  # Placeholder root file system — REQUIRED for evaluation (hostChecks / per-host gate).
  # Replace device + fsType with the target machine's `blkid` output before
  # the first deploy.  lib.mkDefault so a real nixos-generate-config output
  # (plain assignment, higher priority) overrides this cleanly.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}
