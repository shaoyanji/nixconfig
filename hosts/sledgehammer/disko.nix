# Disk layout for USB stick — f2fs for flash longevity.
{device ? throw "Set this to your USB device, e.g. /dev/sdb", ...}: {
  disko.devices = {
    disk.usb = {
      inherit device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            name = "boot";
            size = "1M";
            type = "EF02"; # BIOS boot
          };
          esp = {
            name = "ESP";
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            name = "root";
            size = "100%";
            content = {
              type = "filesystem";
              format = "f2fs";
              mountpoint = "/";
              mountOptions = ["noatime" "nodiratime"];
            };
          };
        };
      };
    };
  };
}
