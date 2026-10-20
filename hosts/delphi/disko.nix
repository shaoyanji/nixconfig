# Declarative disk layout for delphi (OCI Ampere A1, VirtIO boot volume).
#
# fileSystems are owned by THIS file (imported into the flake; see
# flake/host-inventory.nix) — do not add fileSystems entries to
# hardware-configuration.nix. A host that declares mounts in both places has
# two equal-priority definitions of the same option, which is an eval error,
# not a pick.
#
# nixos-anywhere runs disko automatically when the flake output has the disko
# module, so installation is:
#   nix run github:nix-community/nixos-anywhere -- --flake .#delphi --target-host ubuntu@<ip>
#
# The device is an install-time fact: VERIFY it with `lsblk` on the instance
# before running anything, and adjust the argument in flake/host-inventory.nix
# if needed (disko WIPES the disk). Paravirtualized OCI volumes usually appear
# as /dev/sda; virtio-scsi/BM shapes expose /dev/nvme0n1.
#
# NOTE: the disko `filesystem` content type has NO `label` option (verified by
# evaluation on 2026-10-20 — `…content.label` does not exist). A stable
# /dev/disk/by-partlabel handle comes from the PARTITION `name`, which is what
# these names are for.
{device ? "/dev/sda", ...}: {
  disko.devices.disk.main = {
    inherit device;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          name = "ESP";
          type = "EF00";
          size = "1G";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [
              "fmask=0077"
              "dmask=0077"
            ];
          };
        };
        root = {
          name = "root";
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            mountOptions = ["noatime"];
          };
        };
      };
    };
  };
}
