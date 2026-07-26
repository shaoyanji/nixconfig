# Demo — travel netbook.
# Do not import hardware scan; use generic laptop profile instead.
#
# fileSystems."/" is a placeholder so the configuration evaluates cleanly.
# Replace device/fsType with the actual partition layout for the travel
# netbook before deploying. If you eventually import a real hardware scan
# (nixos-generate-config), delete this block.
{ ... }: {
  imports = [
    ../../modules/profiles/laptop.nix
  ];

  fileSystems."/" = {
    # placeholder — adjust to actual hardware at deploy
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
