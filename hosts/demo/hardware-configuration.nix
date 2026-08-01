# Demo — travel netbook.
# Do not import hardware scan; use generic laptop profile instead.
{ lib
, ...
}: {
  imports = [
    ../../modules/profiles/laptop.nix
  ];

  # Placeholder root file system — REQUIRED for evaluation (host-eval-all).
  # Replace device + fsType with the target machine's `blkid` output before
  # deployment.  lib.mkDefault so a real nixos-generate-config output
  # (plain assignment, higher priority) overrides this cleanly.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
