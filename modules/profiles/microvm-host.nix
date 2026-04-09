# Shared microVM host networking configuration.
# Provides the microbr bridge profile, NetworkManager dispatcher script,
# and NAT/firewall rules needed for tap-based microVMs.
#
# Parameters (via function import):
#   natExternalInterface   - WiFi/Ethernet uplink for NAT (e.g. "wlp4s0")
#   microvmExternalInterface - Uplink for microvm.network bridge (e.g. "eno1")
#   bridgeAddress          - IPv4 address for the bridge (default "192.168.83.1/24")
{
  natExternalInterface ? throw "Set natExternalInterface to your uplink (e.g. wlp4s0)",
  microvmExternalInterface ? "eno1",
  bridgeAddress ? "192.168.83.1/24",
  pkgs,
  ...
}: {
  # MicroVM module networking
  microvm.network = {
    enable = true;
    bridgeName = "microbr";
    externalInterface = microvmExternalInterface;
  };

  # NetworkManager bridge profile
  networking.networkmanager.ensureProfiles.profiles = {
    "microbr" = {
      connection = {
        id = "microbr";
        type = "bridge";
        interface-name = "microbr";
        autoconnect = true;
      };
      bridge = {
        stp = false;
        forward-delay = 0;
      };
      ipv4 = {
        method = "manual";
        address1 = bridgeAddress;
      };
      ipv6 = {
        method = "disabled";
      };
    };
  };

  # Auto-add microvm* interfaces to microbr bridge
  environment.etc."NetworkManager/dispatcher.d/10-microvm-bridge".text = ''
    #!/usr/bin/env bash
    INTERFACE="$1"
    ACTION="$2"
    if [[ "$ACTION" == "up" ]] && [[ "$INTERFACE" == microvm* ]]; then
      sleep 1
      if ! ${pkgs.iproute2}/bin/ip link show "$INTERFACE" | grep -q "master microbr"; then
        ${pkgs.iproute2}/bin/ip link set "$INTERFACE" master microbr
      fi
    fi
  '';
  environment.etc."NetworkManager/dispatcher.d/10-microvm-bridge".mode = "0755";

  # NAT for VM network
  networking.nat = {
    enable = true;
    internalInterfaces = ["microbr"];
    externalInterface = natExternalInterface;
  };
  networking.firewall.trustedInterfaces = ["microbr"];
}
