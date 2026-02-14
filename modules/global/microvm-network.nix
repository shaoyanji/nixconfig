{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.microvm = {
    network = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable microvm network bridge and NAT";
      };
      bridgeName = lib.mkOption {
        type = lib.types.str;
        default = "microbr";
        description = "Bridge name to use for VMs";
      };
      externalInterface = lib.mkOption {
        type = lib.types.str;
        default = "eno1";
        description = "External network interface to NAT through";
      };
    };
  };

  # Note: NAT and firewall are configured in the host's configuration.nix
  # This module just documents the options
  config = lib.mkIf config.microvm.network.enable {
    # systemd.network won't work with NetworkManager, but kept for reference
  };
}
