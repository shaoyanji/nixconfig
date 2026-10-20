# Disk layout for stark (Dell Inspiron 24 3477 All-in-One).
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
