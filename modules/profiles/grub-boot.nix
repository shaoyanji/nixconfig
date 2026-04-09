# GRUB bootloader profile for hosts that use BIOS/legacy boot
# instead of systemd-boot EFI.  Overrides the default bootloader
# configured by base-desktop-environment.nix.
#
# Parameters:
#   device - GRUB target device (e.g. "/dev/sda" for BIOS, "nodev" for EFI GRUB)
#   lib    - nixpkgs lib (required)
{
  device ? "/dev/sda",
  lib,
  ...
}: {
  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    efi.canTouchEfiVariables = lib.mkForce false;
    grub = {
      inherit device;
      enable = true;
    };
  };
}
