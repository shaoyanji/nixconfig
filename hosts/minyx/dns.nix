# minyx — the fleet's P1 (priority 1) DNS failover for the *.frieren.lan zone.
# blocky answers the zone and keepalived floats 192.168.3.53 onto it, so clients
# learn one address instead of two they mostly never try. Why blocky here and not
# frieren's FTL stack: docs/dns-failover.md.
{lib, ...}: {
  imports = [../../modules/net/dns/failover.nix];

  profiles.dnsFailover = {
    enable = true;
    role = "secondary";
    backend = "blocky";
    # The wired NIC, which is the preferred path (hosts/minyx/custompi.nix pins
    # the NetworkManager profile to it). VRRP runs here too: advertise, and
    # become MASTER, on one interface only.
    lanInterface = "enu1u1";

    zone = "frieren.lan";
    zoneAddress = "192.168.3.25";

    # The P1. keepalived elects the highest priority, so this node can never
    # take the address from a healthy frieren (200), and claims it as soon as
    # frieren's resolver stops answering the zone.
    secondaryPriority = 1;

    # The address clients point at. It is NOT frieren's own 192.168.3.25: that
    # address stays the target of every *.frieren.lan record, so moving the VIP
    # cannot move the NAS with it.
    virtualIp = "192.168.3.53";
    virtualRouterId = 53;

    # The same static records frieren adds as `address=` lines, in blocky's
    # dialect. A failover that NXDOMAINs a name the primary answers is not a
    # failover — it is a second, quieter outage.
    customRecords = {
      "eisen.lan" = "100.119.172.99";
      "laya.lan" = "100.119.172.99";
      "tts.lan" = "100.119.172.99";
    };

    # Frieren's two lists, verbatim: a client that fails over must get the same
    # answer for an ad domain, or the failover silently stops blocking.
    blocklists = [
      "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts"
      "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt"
    ];
  };

  # A pathological blocklist must not take the failover node down with it: the
  # address this process answers on is the one clients were told to use when the
  # primary is already gone. 256M is roughly four times its measured working set
  # and a quarter of the box.
  systemd.services.blocky.serviceConfig = {
    MemoryMax = "256M";
    # nixpkgs sets `on-failure`. A resolver that exits cleanly is still a
    # resolver that stopped answering, so it restarts either way — the same
    # reason frieren's pihole-ftl is `always`.
    Restart = lib.mkForce "always";
  };

  # Gap, by backend design: blocky has no dnsmasq-style conditional forward, so the
  # tailnet zone and `gok` resolve through frieren only (docs/dns-failover.md).
  # The 53 hole is the module's (interfaces.enu1u1); nothing opens wlan0, because
  # the VIP lives on enu1u1 and an answer over wifi is one nobody can route to.
}
