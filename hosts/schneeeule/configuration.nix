{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia.nix
    ../common/steam.nix
    ../common/impermanence.nix
    ../common/base-desktop-environment.nix
  ];
  networking.hostName = "schneeeule"; # Define your hostname.
  environment.systemPackages = with pkgs; [
  ];

  fileSystems."/persist/data" = {
    device = "/dev/disk/by-uuid/ae50ae59-36e2-4e9a-88d0-04951f6a51fc";
    fsType = "ext4";
  };
  virtualisation.incus.preseed = {
    networks = [
      {
        config = {
          "ipv4.address" = "10.0.100.1/24";
          "ipv4.nat" = "true";
        };
        name = "incusbr0";
        type = "bridge";
      }
    ];
    profiles = [
      {
        devices = {
          eth0 = {
            name = "eth0";
            network = "incusbr0";
            type = "nic";
          };
          root = {
            path = "/";
            pool = "default";
            size = "35GiB";
            type = "disk";
          };
        };
        name = "default";
      }
    ];
    storage_pools = [
      {
        config = {
          #        source = "/var/lib/incus/storage-pools/default";
          source = "/persist/data";
        };
        driver = "dir";
        name = "default";
      }
    ];
  };

  i18n.extraLocaleSettings = {
    LC_NUMERIC = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };
  system.stateVersion = "24.11"; # Did you read the comment?
}
