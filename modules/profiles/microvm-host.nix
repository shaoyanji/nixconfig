# Shared microVM host networking: NM-owned bridge, udev-attached taps, NAT.
# A dispatcher cannot do the taps (NM emits no event for an unmanaged one), so
# udev attaches them. Shape: Stapelberg's microvm.nix with NM as bridge owner.
{
  natExternalInterface ? throw "Set natExternalInterface to your uplink (e.g. wlp4s0)",
  microvmExternalInterface ? "eno1",
  bridgeAddress ? "192.168.83.1/24",
  ...
}: {
  config,
  lib,
  pkgs,
  ...
}: let
  bridge = config.microvm.network.bridgeName;
in {
  options.microvm.network = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable microvm network bridge and NAT";
    };
    bridgeName = lib.mkOption {
      type = lib.types.str;
      default = "brlan";
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
      bridgeName = "brlan";
      externalInterface = microvmExternalInterface;
    };

    # One declarative keyfile profile. NM creates and owns the bridge, gives it
    # the gateway address, and keeps STP off so a guest is reachable immediately.
    networking.networkmanager.ensureProfiles.profiles.${bridge} = {
      connection = {
        id = bridge;
        type = "bridge";
        interface-name = bridge;
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

    # NM does not manage taps, so it must not race the udev rule for them.
    networking.networkmanager.unmanaged = ["interface-name:microvm*"];

    # The add event fires when microvm-tap-interfaces@ creates the tap, which is
    # the one place a tap reliably produces an event. Runs `ip`, not `nmcli`:
    # the bridge is a kernel device by then and NM owns the profile, not the port.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="net", KERNEL=="microvm*", RUN+="${pkgs.iproute2}/bin/ip link set %k master ${bridge}"
    '';

    networking.nat = {
      enable = true;
      internalInterfaces = [bridge];
      externalInterface = natExternalInterface;
    };
    networking.firewall.trustedInterfaces = [bridge];
  };
}
