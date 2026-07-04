# Disk layout for netbook — f2fs root on flash with swap partition.
# GPT with ESP + swap + f2fs root. Device path is parameterised.
{
  device ? throw "Set this to your disk device, e.g. /dev/nvme0n1 or /dev/sda",
  ...
}: {
  disko.devices = {
    disk.main = {
      inherit device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            name = "boot";
            size = "1M";
            type = "EF02";
          };
          esp = {
            name = "ESP";
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["fmask=0022" "dmask=0022"];
            };
          };
          swap = {
            size = "4G";
            content = {
              type = "swap";
              resumeDevice = true;
            };
          };
          root = {
            name = "root";
            size = "100%";
            content = {
              type = "filesystem";
              format = "f2fs";
              mountpoint = "/";
              mountOptions = ["noatime"];
            };
          };
        };
      };
    };
  };
}
