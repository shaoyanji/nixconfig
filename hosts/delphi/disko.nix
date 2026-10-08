# Declarative disk layout for delphi (OCI Ampere A1, VirtIO boot volume).
#
# Not imported by hardware-configuration.nix (the runtime fileSystems there
# stay authoritative once the host is installed). This file exists for
# nixos-anywhere provisioning of a fresh instance:
#   nix run github:nix-community/nixos-anywhere -- \
#     --flake .#delphi --disko hosts/delphi/disko.nix <target>
{device ? "/dev/sda", ...}: {
  disko.devices.disk.main = {
    inherit device;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
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
