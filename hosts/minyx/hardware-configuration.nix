# minyx — Raspberry Pi 3 Model B, system disk on a USB stick (OTP USB boot).
#
# This imports the *generic* sd-card image module, not sd-image-aarch64.nix.
# The aarch64 wrapper also imports nixos/modules/profiles/base.nix — "software
# packages included in the minimal installation CD" — which installs a
# 25-package emergency repair kit (vim, testdisk, ddrescue, efibootmgr, w3m,
# cryptsetup, ...) and switches on nine filesystem types. Measured on this host:
# 70 MB of direct packages, plus samba (119 MB) via cifs-utils and the zfs/xfs/
# nfs/lvm tooling. A jump box that is reflashed, never repaired in place, pays
# for none of it.
#
# Two halves of the image are therefore owned elsewhere, deliberately:
#   - the FAT firmware partition by nixos-hardware's raspberry-pi module
#     (`sdImage.populateFirmwareCommands`, which it sets with mkForce);
#   - /boot on the root partition here, via extlinux. That is the piece
#     sd-image-aarch64.nix would otherwise have supplied.
{
  config,
  modulesPath,
  ...
}: {
  imports = [(modulesPath + "/installer/sd-card/sd-image.nix")];

  sdImage = {
    # dd'd to a USB stick of any size; the root partition grows to fill the
    # device on first boot, so the image itself stays small.
    expandOnBoot = true;
    compressImage = true;
    rootVolumeLabel = "NIXOS_SD";

    # extlinux + kernel + initrd on the root partition. generic-extlinux-
    # compatible.enable is set by the raspberry-pi module.
    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';
  };

  nixpkgs.hostPlatform = "aarch64-linux";
}
