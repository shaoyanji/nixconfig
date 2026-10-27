# minyx — Raspberry Pi 3 Model B, system disk on a USB stick (OTP USB boot).
# Imports generic sd-image.nix with extlinux bootloader on root partition.
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
