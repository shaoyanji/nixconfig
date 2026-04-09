{config, lib, pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.generic-extlinux-compatible.enable = true;

  system.stateVersion = "24.11";
}
