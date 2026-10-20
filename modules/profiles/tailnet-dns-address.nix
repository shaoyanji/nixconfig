# Bind the shared tailnet DNS service address on lo.
#
# Tailscale has no concept of a floating address, so a resolver pair that clients
# can point at with ONE address needs a trick: both nodes bind the same /32 on
# lo and advertise it as the SAME subnet route. Tailscale then treats the two
# advertisements as a failover set and moves the route to the survivor within
# ~15 s. Listing two nameservers in the tailnet settings does not work — clients
# would not retry fast enough and a dead first entry breaks DNS outright.
#
# The address is deliberately outside 100.64/10: it must not be confused with a
# node's own tailnet address, or packets take the local-interface shortcut and
# never reach the other node.
#
# This module owns only the `lo` bind. What answers on it is the host's own
# resolver (pihole-ftl on frieren, crab-hole on delphi), and the route
# advertisement stays a `--advertise-routes=` flag on the host, because that flag
# is also where the host declares its other routes.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.profiles.tailnetDnsAddress;
in {
  options.profiles.tailnetDnsAddress = {
    enable = lib.mkEnableOption "bind the shared tailnet DNS service address on lo";

    # The BARE address, no prefix: the same value hosts already pass to their
    # `--advertise-routes=<addr>/32` flag, so there is one spelling of the fact.
    # This module adds the /32 where the kernel wants one.
    address = lib.mkOption {
      type = lib.types.str;
      default = "10.99.0.53";
      description = ''
        The address both resolver nodes bind and advertise. Must be identical on
        every member of the failover group, must be a bare IPv4 address, and
        must not be inside 100.64/10.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(lib.hasInfix "/" cfg.address);
        message = "profiles.tailnetDnsAddress.address must be a bare IPv4 address, no prefix (got '${cfg.address}').";
      }
      {
        assertion = !(lib.hasPrefix "100." cfg.address);
        message = "profiles.tailnetDnsAddress.address must not be a tailnet member address (100.64.0.0/10).";
      }
    ];

    # `ip addr replace` is idempotent, which matters: this runs on every boot and
    # must not fail when the address is already present.
    systemd.services.dns-service-address = {
      description = "Tailnet DNS service address ${cfg.address}/32";
      wantedBy = ["multi-user.target"];
      after = ["network-pre.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.iproute2}/bin/ip addr replace ${cfg.address}/32 dev lo";
        ExecStop = "${pkgs.iproute2}/bin/ip addr del ${cfg.address}/32 dev lo";
      };
    };
  };
}
