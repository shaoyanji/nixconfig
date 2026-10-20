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
# This module owns the `lo` bind AND the advertisement of that /32. What answers
# on it is the host's own resolver (pihole-ftl on frieren, crab-hole on delphi),
# which stays a host decision.
#
# The advertisement is composed here rather than hand-written per host because
# the two facts — "bind it" and "advertise it" — must never diverge. They did:
# setting only `.address` leaves the bind behind `enable`, and a hand-written
# flag can advertise a route the other member does not (or forget the /32
# entirely while the group still looks configured). The host now contributes
# only its *own* routes; this module appends the service /32 and emits the one
# comma-separated flag, so `tailscale set` (which REPLACES the whole route set)
# can never be handed two competing flags.
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

    advertiseRoutes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["192.168.3.0/24"];
      description = ''
        This host's OWN routes, advertised alongside the service /32. The /32 is
        appended automatically — do not list it here, and do not hand-write a
        `--advertise-routes=` flag in `services.tailscale.extraSetFlags`. Leave
        empty on a host that is only a resolver (an exit node's `0.0.0.0/0` is
        covered by {option}`exitNode`, not by this list).
      '';
    };

    exitNode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Advertise this host as an exit node. Kept as its own option because
        `--advertise-exit-node` is a flag, not a route, and OCI egress is billed:
        an accidental exit node is a bandwidth decision, not a typo.
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
      # Exactly one --advertise-routes flag may reach `tailscale set`. A second
      # one is not a merge: the last flag wins and silently drops the rest.
      {
        assertion =
          lib.count (f: lib.hasPrefix "--advertise-routes=" f) config.services.tailscale.extraSetFlags == 1;
        message = "profiles.tailnetDnsAddress composes the --advertise-routes flag; remove the hand-written one from services.tailscale.extraSetFlags and list host routes in profiles.tailnetDnsAddress.advertiseRoutes instead.";
      }
    ];

    # One flag, comma-separated — `tailscale set --advertise-routes` REPLACES
    # the whole set, so two flags would leave only the last one in force.
    services.tailscale.extraSetFlags =
      [
        "--advertise-routes=${lib.concatStringsSep "," (cfg.advertiseRoutes ++ ["${cfg.address}/32"])}"
      ]
      ++ lib.optional cfg.exitNode "--advertise-exit-node";

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
