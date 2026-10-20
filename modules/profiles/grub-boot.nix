# GRUB bootloader profile for hosts that use BIOS/legacy boot
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
