# Disk layout for fern (HP 15 laptop, Ryzen 3 3250U).
#
# Single SSD (SATA M.2 / 2.5" — most HP 15s-eq units enumerate it as
# /dev/sda; NVMe units would be /dev/nvme0n1 — verify with `lsblk` and
# adjust the device argument in flake/host-inventory.nix BEFORE
# formatting; disko wipes the disk).
#
# Shape mirrors stark's system disk: UEFI ESP + 8G swap (>= 8 GB RAM,
# so hibernation stays possible) + btrfs /root + /nix subvolumes.
# Host-local on purpose (TODO.md → "Things To Avoid": storage layouts
# stay host-specific). Persistent desktop — no impermanence.
{device ? throw "Set this to the laptop SSD, e.g. /dev/sda or /dev/nvme0n1"}: {
  disko.devices = {
    disk.main = {
      inherit device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          esp = {
            name = "ESP";
            size = "500M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["fmask=0022" "dmask=0022"];
            };
          };
          swap = {
            size = "8G";
            content = {
              type = "swap";
              resumeDevice = true;
            };
          };
          root = {
            name = "root";
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = ["-f"];
              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                  mountOptions = ["compress=zstd" "noatime"];
                };
                "/nix" = {
                  mountOptions = ["subvol=nix" "compress=zstd" "noatime"];
                  mountpoint = "/nix";
                };
              };
            };
          };
        };
      };
    };
  };
}
