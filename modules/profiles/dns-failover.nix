# DNS high availability: one reusable, role-based resolver stack (HC-3).
#
# frieren is the fleet's only resolver. It answers `*.frieren.lan`
# (`address=/frieren.lan/192.168.3.25`) and does ad-blocking (`pihole-ftl` →
# `unbound` on `127.0.0.1#5335`) from a single host, so losing frieren breaks
# name resolution for every client that points at it. This module makes that
# stack reusable so a second always-on host can serve the *same* answers, and
# gives the primary/secondary relationship a declaration instead of two
# hand-synced copies.
#
# Failover has two shapes, chosen by `virtualIp`:
#   * `virtualIp = null` (default) — client-side. Clients are handed the whole
#     `resolvers` list (primary first) and retry the next one when the first
#     stops answering. Nothing floats, so nothing can split.
#   * `virtualIp = "…"` — VRRP via keepalived. Both hosts advertise one virtual
#     address; the primary holds it and a DNS-aware `vrrp_script` demotes it the
#     moment its local resolver stops answering (a NIC that stays up while
#     pihole-ftl dies is exactly the failure a link check misses).
#
# Split brain is prevented structurally, not by convention:
#   * `role` is an enum, so a host is exactly one of primary/secondary;
#   * `virtualRouterId` is REQUIRED once `virtualIp` is set — two hosts that
#     advertise the same address under *different* router ids are two separate
#     one-node VRRP groups that both elect themselves MASTER, which is exactly
#     split brain (asserted below);
#   * `primaryPriority` must exceed `secondaryPriority`, so a partition cannot
#     promote a backup while the primary is still healthy.
# The VRRP outcome itself is a runtime fact, so the final check is operational,
# not declarative: `scripts/task/dns-failover-check.sh` fails if the group
# answers from two places at once (duplicate-address probe on the VIP).
#
# This module owns the MECHANISM: unbound + the pihole-ftl core settings + the
# zone wildcard + the LAN firewall hole + optional VRRP. Host POLICY stays on
# the host and is passed in, so the module never guesses: extra `dnsmasq_lines`
# (`extraDnsmasqLines` — extra `address=` records, the tailscale0 `interface=`
# line, the PXE proxyDHCP lines), blocklists, the web UI and log deleter, and
# any non-LAN firewall interfaces.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.profiles.dnsFailover;

  isPrimary = cfg.role == "primary";

  # A DNS-aware liveness probe: demote the node whose *resolver* died, not the
  # one whose link flapped. Dig the zone this resolver is authoritative for.
  dnsProbe = pkgs.writeShellScript "dns-vrrp-probe" ''
    set -eu
    exec ${pkgs.dnsutils}/bin/dig +time=2 +tries=1 -4 @127.0.0.1 "${cfg.zone}" A >/dev/null
  '';

  vrrpPriority =
    if isPrimary
    then cfg.primaryPriority
    else cfg.secondaryPriority;
in {
  options.profiles.dnsFailover = {
    enable = lib.mkEnableOption "the role-based DNS resolver stack (HC-3)";

    role = lib.mkOption {
      type = lib.types.enum ["primary" "secondary"];
      default = "secondary";
      description = ''
        This host's role in the resolver group. Exactly one host is `primary`
        (frieren); every additional resolver is a `secondary`.
      '';
    };

    lanInterface = lib.mkOption {
      type = lib.types.str;
      example = "enp1s0";
      description = ''
        LAN interface Pi-hole FTL answers on. Also the interface DNS is opened
        on in the firewall and, when {option}`virtualIp` is set, the VRRP
        interface.
      '';
    };

    zone = lib.mkOption {
      type = lib.types.str;
      default = "frieren.lan";
      description = "Wildcard zone this resolver owns.";
    };

    zoneAddress = lib.mkOption {
      type = lib.types.str;
      default = "192.168.3.25";
      description = ''
        Address every name under {option}`zone` resolves to — the dnsmasq
        `address=/<zone>/<addr>` line.
      '';
    };

    resolvers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["192.168.3.25" "192.168.3.26"];
      description = ''
        Ordered resolver addresses clients should be configured with, primary
        first. Advisory: the module does not push these to clients. They exist so
        the runbook and `checks:dns:failover` read the group from one place.
      '';
    };

    extraDnsmasqLines = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Host-specific dnsmasq lines appended after the zone wildcard — extra
        `address=` records, the `interface=tailscale0` line, PXE proxyDHCP.
        Kept as an input so the module never has to guess the host's policy.
      '';
    };

    virtualIp = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "192.168.3.53";
      description = ''
        Optional VRRP virtual IP shared by the primary and its secondaries.
        When null, failover is client-side via {option}`resolvers`. Setting it
        enables keepalived and therefore requires {option}`virtualRouterId`.
      '';
    };

    virtualRouterId = lib.mkOption {
      type = lib.types.nullOr (lib.types.ints.between 1 255);
      default = null;
      description = ''
        VRRP router id shared by every host in the group. Required when
        {option}`virtualIp` is set; hosts that disagree on it are separate
        one-node groups and both become MASTER.
      '';
    };

    unicastPeers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Peer resolver addresses for unicast VRRP. Preferred over multicast on a
        network that filters 224.0.0.18, which silently splits a multicast group.
      '';
    };

    primaryPriority = lib.mkOption {
      type = lib.types.ints.between 1 255;
      default = 150;
      description = "VRRP priority of the primary. Must exceed {option}`secondaryPriority`.";
    };

    secondaryPriority = lib.mkOption {
      type = lib.types.ints.between 1 255;
      default = 100;
      description = "VRRP priority of a secondary.";
    };
  };

  config = lib.mkIf cfg.enable {
    # --- resolver core (identical on every role) ------------------------------
    services.unbound = {
      enable = true;
      # Pi-hole forwards to this explicitly; unbound must not also grab the host
      # resolver stub, which would fight systemd-resolved.
      resolveLocalQueries = false;
      settings.server = {
        interface = ["127.0.0.1@5335"];
        access-control = ["127.0.0.0/8 allow"];
      };
    };

    services.pihole-ftl = {
      enable = true;
      settings = {
        dns = {
          queryLogging = true;
          upstreams = ["127.0.0.1#5335"];
          listeningMode = "ALL";
          interface = cfg.lanInterface;
        };
        database.maxDBdays = 31;
        misc.dnsmasq_lines = ["address=/${cfg.zone}/${cfg.zoneAddress}"] ++ cfg.extraDnsmasqLines;
      };
    };

    # DNS is reachable on the LAN interface only; other interfaces (tailscale0,
    # a second LAN NIC) are the host's business, not this module's guess.
    networking.firewall.interfaces.${cfg.lanInterface} = {
      allowedTCPPorts = [53];
      allowedUDPPorts = [53];
    };

    # --- optional VRRP failover -----------------------------------------------
    # Gated on BOTH values: emitting the instance with a null router id would hit
    # the option's type checker before the split-brain assertion could explain
    # itself. With this gate the incomplete config still evaluates, so the
    # `virtualIp without virtualRouterId` assertion below is the error you see.
    services.keepalived = lib.mkIf (cfg.virtualIp != null && cfg.virtualRouterId != null) {
      enable = true;
      # Opens VRRP (proto 112). On a `mkForce`-scoped host this global hole is
      # cleared — add 112 to that host's per-interface list as well.
      openFirewall = true;
      vrrpScripts.dns = {
        script = toString dnsProbe;
        interval = 5;
        timeout = 3;
        rise = 2;
        fall = 2;
        # Negative weight only ever demotes a failing node — it can never lift a
        # broken resolver above a healthy primary.
        weight = -60;
      };
      vrrpInstances.dns = {
        interface = cfg.lanInterface;
        state =
          if isPrimary
          then "MASTER"
          else "BACKUP";
        inherit (cfg) virtualRouterId unicastPeers;
        priority = vrrpPriority;
        virtualIps = [{addr = cfg.virtualIp;}];
        trackScripts = ["dns"];
      };
    };

    assertions = [
      {
        assertion = cfg.zone != "" && !(lib.hasInfix "/" cfg.zone);
        message = "profiles.dnsFailover.zone must be a bare domain (no slash), got '${cfg.zone}'.";
      }
      {
        assertion = cfg.zoneAddress != "";
        message = "profiles.dnsFailover.zoneAddress must not be empty.";
      }
      {
        assertion = cfg.virtualIp == null || cfg.virtualRouterId != null;
        message = ''
          profiles.dnsFailover: virtualIp is set without virtualRouterId. Two
          hosts advertising the same address under different router ids are two
          one-node VRRP groups that both become MASTER — i.e. split brain.
        '';
      }
      {
        assertion = cfg.virtualRouterId == null || cfg.virtualIp != null;
        message = "profiles.dnsFailover.virtualRouterId has no effect without virtualIp.";
      }
      {
        assertion = cfg.primaryPriority > cfg.secondaryPriority;
        message = ''
          profiles.dnsFailover.primaryPriority (${toString cfg.primaryPriority})
          must exceed secondaryPriority (${toString cfg.secondaryPriority}), or a
          partition can promote a backup while the primary is still healthy.
        '';
      }
    ];
  };
}
