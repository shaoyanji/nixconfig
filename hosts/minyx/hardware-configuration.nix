# minyx — Raspberry Pi 3 Model B, system disk on a USB stick (OTP USB boot).
#
# NixOS does not "install" a Pi bootloader: sd-image-aarch64.nix assembles the
# FAT firmware partition itself (bootcode.bin, start*.elf, fixup*.dat, the
# bcm2710-rpi-3-b DTB, u-boot and a generated config.txt) and extlinux then hands
# over to the kernel. That blob-copying logic exists only upstream, so this host
# imports it instead of re-implementing it, which is also why there is no
# hand-written fileSystems block here any more.
{modulesPath, ...}: {
  imports = [(modulesPath + "/installer/sd-card/sd-image-aarch64.nix")];

  sdImage = {
    # dd'd to a USB stick of any size; the root partition grows to fill the
    # device on first boot, so the image itself stays small.
    expandOnBoot = true;
    compressImage = true;
    rootVolumeLabel = "NIXER";
  };

  # /nix is a directory on that root filesystem, not a separate mount. The btrfs
  # subvolume layout (@nix / @persist) is a later, separate change: it swaps
  # sdImage.rootFilesystemCreator and overrides fileSystems."/", which also
  # needs sdImage.nixPathRegistrationFile pointing at the root mount.
  nixpkgs.hostPlatform = "aarch64-linux";
}
