# stark — hand-written hardware-configuration (not from a real
# nixos-generate-config scan yet; revisit after first boot).
#
# fileSystems are owned by ./disko.nix (SSD system + 1 TB HDD Steam
# library) — do not add fileSystems entries here.
{ config
, lib
, modulesPath
, ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Kaby Lake-U (i5-7200U) AIO: SK hynix SC311 is an M.2 SATA drive —
  # it enumerates via ahci (NOT nvme), but keep nvme in the initrd in
  # case the unit ships with an NVMe module instead. ahci also covers
  # the 1 TB HDD; xhci_pci for USB peripherals.
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
