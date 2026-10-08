# Disk layout for stark (Dell Inspiron 24 3477 All-in-One).
#
# Dual-disk:
#   main: SK hynix SC311 SATA SSD (128 GB) — system disk.
#     Persistent ID: /dev/disk/by-id/ata-SK_hynix_SC311_SATA_128GB_MS83N428510303B5B
#     UEFI ESP + 8G swap + btrfs /root + /nix subvolumes (no LVM).
#   hdd: 1 TB HDD (Seagate ST1000LM035) — dedicated Steam library,
#     Persistent ID: /dev/disk/by-id/ata-ST1000LM035-1RK172_WL14QR63
#     single btrfs partition mounted at /mnt/steam.
#
# Host-local on purpose: disk topology is host-specific (TODO.md →
# "Things To Avoid" — do not merge host-local storage layouts into
# shared modules). Shape mirrors hosts/common/disko.nix minus the LVM
# and /persist: stark is a persistent eisen-style Steam desktop and
# does NOT run impermanence.
#
# WARNING: `disko` wipes BOTH disks. Always use deterministic by-id paths
# or verify with `lsblk` before running disko — SCSI drive letters (/dev/sdX)
# can swap between boots.
{
  mainDevice ? "/dev/disk/by-id/ata-SK_hynix_SC311_SATA_128GB_MS83N428510303B5B",
  hddDevice ? "/dev/disk/by-id/ata-ST1000LM035-1RK172_WL14QR63",
}: {
  disko.devices = {
    disk.main = {
      device = mainDevice;
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
    disk.hdd = {
      device = hddDevice;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          steam = {
            name = "steam";
            size = "100%";
            content = {
              type = "filesystem";
              format = "btrfs";
              extraArgs = ["-f" "-L" "steam"];
              mountpoint = "/mnt/steam";
              mountOptions = ["compress=zstd" "noatime" "autodefrag"];
            };
          };
        };
      };
    };
  };
}
