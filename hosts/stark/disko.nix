# Disk layout for stark (Dell Inspiron 24 3477 All-in-One).
#
# Dual-disk:
#   main: SK hynix SC311 SATA SSD — system disk. The 3477's kernel
#     enumerates the 1 TB HDD first, so the inventory passes the SSD as
#     /dev/sdb (verify with lsblk -o NAME,SIZE,MODEL before disko).
#     UEFI ESP + 8G swap + btrfs /root + /nix subvolumes (no LVM).
#   hdd: 1 TB HDD (/dev/sda) — dedicated Steam library,
#     single btrfs partition mounted at /mnt/steam.
#
# Host-local on purpose: disk topology is host-specific (TODO.md →
# "Things To Avoid" — do not merge host-local storage layouts into
# shared modules). Shape mirrors hosts/common/disko.nix minus the LVM
# and /persist: stark is a persistent eisen-style Steam desktop and
# does NOT run impermanence.
#
# WARNING: `disko` wipes BOTH disks. Verify with `lsblk` before
# running the disko script — the SSD must be main (/dev/sdb), the
# 1 TB HDD hdd (/dev/sda).
{ mainDevice ? throw "Set mainDevice to the system SSD, e.g. /dev/sda"
, hddDevice ? throw "Set hddDevice to the 1 TB HDD, e.g. /dev/sdb"
,
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
              mountOptions = [ "fmask=0022" "dmask=0022" ];
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
              extraArgs = [ "-f" ];
              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
                "/nix" = {
                  mountOptions = [ "subvol=nix" "compress=zstd" "noatime" ];
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
              extraArgs = [ "-f" "-L" "steam" ];
              mountpoint = "/mnt/steam";
              mountOptions = [ "compress=zstd" "noatime" "autodefrag" ];
            };
          };
        };
      };
    };
  };
}
