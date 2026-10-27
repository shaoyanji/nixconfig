# minyx — DNS failover for *.frieren.lan: blocky answers the zone, keepalived
# floats the VIP at priority 1 so it can only take over from a dead primary.
# Preconditions (reserved addresses, narrowed pool) and test: docs/dns-failover.md.
{lib, ...}: {
  imports = [../../modules/net/dns/failover.nix];

  profiles.dnsFailover = {
    enable = true;
    role = "secondary";
    backend = "blocky";
    # The wifi link, verified on the board 2026-10-27: `wlan0` UP with
    # 192.168.3.3, `enu1u1` DOWN (no cable). Binding the role to the wired NIC
    # would have been a silent no-op — 53 closed there, keepalived advertising
    # into a dead link. VRRP over 2.4 GHz is best-effort: a >3 s stall lets both
    # nodes elect MASTER, so watch `journalctl -u keepalived` for flaps.
    lanInterface = "wlan0";

    zone = "frieren.lan";
    zoneAddress = "192.168.3.25";

    # The P1: keepalived elects the highest priority, so this node can never take
    # the address from a healthy frieren (200), and claims it when frieren's
    # resolver stops answering the zone.
    secondaryPriority = 1;

    # Reserved on the router, outside its DHCP pool, and NOT this host's own
    # address or frieren's — see docs/dns-failover.md ("Choosing the VIP").
    virtualIp = "192.168.3.50";
    virtualRouterId = 50;
    # Unicast, not multicast. The module asserts a non-empty list because two
    # nodes that cannot hear each other's adverts both elect MASTER, putting one
    # address on two MACs (frieren, 2026-10-27).
    unicastPeers = ["192.168.3.25"];

    # The same static records frieren answers as `address=` lines, in blocky's
    # dialect: a failover that NXDOMAINs a name the primary answers is a second,
    # quieter outage.
    customRecords = {
      "eisen.lan" = "100.119.172.99";
      "laya.lan" = "100.119.172.99";
      "tts.lan" = "100.119.172.99";
    };

    # Frieren's two lists, verbatim, so a client that falls over keeps blocking.
    blocklists = [
      "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts"
      "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt"
    ];
  };

  # A pathological blocklist must not take down the node whose address clients
  # were told to use when the primary is already gone.
  systemd.services.blocky = {
    # Class declared, not implied — see hosts/frieren/dns.nix for the primary's
    # marker on the same role. nixpkgs sets `on-failure`; a resolver that exits
    # cleanly still stopped answering, so it comes back either way.
    unitConfig = {
      X-Fleet-Role = "daemon";
      StartLimitIntervalSec = 0;
    };
    serviceConfig = {
      MemoryMax = "256M";
      Restart = lib.mkForce "always";
    };
  };

  # Gap, by backend design: blocky has no dnsmasq-style conditional forward, so the
  # tailnet zone and `gok` resolve through frieren only. The 53 hole is the
  # module's (interfaces.wlan0).
}
