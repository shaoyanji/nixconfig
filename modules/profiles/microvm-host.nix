# Shared microVM host networking: bridge, tap attachment, NAT.
{
  natExternalInterface ? throw "Set natExternalInterface to your uplink (e.g. wlp4s0)",
  microvmExternalInterface ? "eno1",
  bridgeAddress ? "192.168.83.1/24",
  ...
}: {lib, ...}: {
  options.microvm.network = {
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

  config = {
    microvm.network = {
      enable = true;
      bridgeName = "microbr";
      externalInterface = microvmExternalInterface;
    };

    # DECLARATIVE, because the imperative version does not survive a reboot:
    # NetworkManager + a dispatcher script that enslaved `microvm*` on "up" never
    # fired (NM does not manage taps), so every rebuild left the bridge with no
    # ports and `ip link set <tap> master microbr` had to be run by hand.
    #
    # networkd owns ONLY this bridge — NetworkManager keeps the uplink. The tap
    # rule is a name match, so a guest added tomorrow needs no network config:
    #   netdev  microbr
    #   network microbr      address, and usable with no carrier
    #   network microvm*     Bridge=microbr
    systemd.network.enable = true;
    systemd.network.netdevs."20-microbr".netdevConfig = {
      Kind = "bridge";
      Name = "microbr";
    };
    systemd.network.networks."20-microbr" = {
      matchConfig.Name = "microbr";
      addresses = [{Address = bridgeAddress;}];
      networkConfig.ConfigureWithoutCarrier = true;
    };
    systemd.network.networks."21-microvm-tap" = {
      matchConfig.Name = "microvm*";
      networkConfig.Bridge = "microbr";
    };
    networking.networkmanager.unmanaged = [
      "interface-name:microbr"
      "interface-name:microvm*"
    ];

    networking.nat = {
      enable = true;
      internalInterfaces = ["microbr"];
      externalInterface = natExternalInterface;
    };
    networking.firewall.trustedInterfaces = ["microbr"];
  };
}
