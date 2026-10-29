# frieren's resolver role: modules/net/dns plus the tailnet failover peer for the
# shared 10.99.0.53, so losing either node does not lose tailnet DNS.
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/net/dns
  ];

  # --- tailnet failover peer for 10.99.0.53 ---------------------------------
  # delphi was built to be the second member of this group; without frieren
  # advertising the same /32 the address is served by delphi alone, so losing
  # delphi loses tailnet DNS. Both nodes bind 10.99.0.53 on lo (the shared
  # module) and advertise it; Tailscale treats the two advertisements as a
  # failover set and moves the route to the survivor (~15 s).
  #
  # pihole-ftl already listens on 0.0.0.0:53, so nothing else has to change for
  # it to answer on the bound address — verified before adding this. The module
  # also advertises the /32; only the LAN route is declared here.
  profiles.tailnetDnsAddress = {
    enable = true;
    advertiseRoutes = ["192.168.3.0/24"];
  };

  # --- primary resolver role (HC-3) -----------------------------------------
  # The reusable resolver core — unbound + pihole-ftl's filtering config + the
  # wildcard zone + the LAN firewall hole — lives in
  # modules/net/dns/failover.nix. frieren is the fleet PRIMARY; host policy
  # (extra address= records, the tailscale interface line, PXE proxyDHCP,
  # blocklists, the web UI) stays here and is fed in.
  #
  # Failover is VRRP: minyx (hosts/minyx/dns.nix) is the second member, MASTER
  # here at 200 and BACKUP there at 1, so it can only take the address when this
  # resolver stops answering the zone. Both halves must be deployed together —
  # the 2026-10-27 outage was one half live on an address nobody had reserved.
  #
  # `192.168.3.50` is a static-block address (below the DHCP pool), not this
  # host's `.25` and not minyx's `.9`: a VIP that duplicates an address already
  # on the wire is a duplicate address, not redundancy. Unicast peers, because
  # multicast VRRP splits brain on this LAN. Preconditions and the test:
  # docs/dns-failover.md.
  profiles.dnsFailover = {
    enable = true;
    role = "primary";
    lanInterface = "enp1s0";
    zone = "frieren.lan";
    zoneAddress = "192.168.3.25";
    # The VIP is the only resolver clients are configured with; `.25` stays what
    # every *.frieren.lan record points at.
    resolvers = ["192.168.3.50"];
    virtualIp = "192.168.3.50";
    virtualRouterId = 50;
    unicastPeers = ["192.168.3.3"];
    primaryPriority = 200;
    extraDnsmasqLines =
      [
        "interface=tailscale0"
        "interface=wlp2s0"
        "interface=enp0s20f0u2u1i5"
        # eisen's local LLM API (llama.cpp OpenAI /v1) resolves to its stable
        # tailnet address; LAN clients reach it over the tailnet.
        "address=/eisen.lan/100.119.172.99"
        # Laya decision model (Jev-compatible /v1/systemone) on eisen; same
        # tailnet address, exposed as its own nginx vhost on :80.
        "address=/laya.lan/100.119.172.99"
        # Qwen3-TTS speech server on eisen (OpenAI-compatible /v1/audio/speech);
        # nginx vhost on :80, tailscale serve :8444.
        "address=/tts.lan/100.119.172.99"
        # The gokrazy appliance has no LAN A record: its name lives in the
        # tailnet. A conditional forward asks MagicDNS (served by the local
        # tailscaled) instead of pinning an address, so `gok update` resolves the
        # instance Hostname and the answer follows the node wherever it moves.
        "server=/gok/100.100.100.100"
        # Whole tailnet zone: every `*.cloudforest-kardashev.ts.net` name is
        # answered by MagicDNS, which follows the node. Without this the fleet
        # resolver returns NXDOMAIN for tailnet FQDNs, so any browser on the LAN
        # gets "Server Not Found" for frieren.<tailnet>.ts.net (measured
        # 2026-10-26: MagicDNS answered, pihole did not).
        "server=/cloudforest-kardashev.ts.net/100.100.100.100"
        # --- Steam content cache (services.steamCache) -----------------------
        # OFF since 2026-10-28: `address=/steamcontent.com/` is the whole zone, so
        # it also swallowed `cm-01-fra1.steamcontent.com` — the connection manager,
        # which no exclusion can carve back out because it is a *sibling* of the
        # download names — and Dota 2 stopped accepting matches. The names and the
        # reasoning live in the module (`steamCache.dnsmasqLines` derives them from
        # `dnsSteer`); this file only splices them in, so the resolver policy has
        # one home. Steering is off by default; `content` is the narrow form.
      ]
      ++ config.services.steamCache.dnsmasqLines
      ++ [
        # --- PXE proxyDHCP for iVentoy (ExternalNet mode on :16000/:69) ---
        # Answer ONLY PXE clients on the LAN; never lease IPs — the Huawei router
        # (192.168.3.1) remains the sole DHCP server. dnsmasq proxy mode
        # waits 2s for the real DHCP server's OFFER and only supplies the
        # PXE boot options the router lacks.
        "dhcp-range=192.168.3.25,proxy,255.255.255.0"
        # /var/lib/misc is read-only on NixOS — without a writable lease file
        # dnsmasq's DHCP subsystem aborts and UDP 67 never binds.
        "dhcp-leasefile=/var/lib/pihole/dnsmasq.leases"
        # Arch-specific boot file -> iVentoy's virtual loader names. The
        # suffix (16000) must match iVentoy's HTTP PXE port.
        "pxe-service=x86PC,\"Boot from network (BIOS)\",iventoy_loader_16000_bios,192.168.3.25"
        "pxe-service=X86-64_EFI,\"Boot from network (UEFI)\",iventoy_loader_16000_uefi,192.168.3.25"
      ];
  };

  # Tailnet DNS should stay manually managed after deployment:
  # sudo tailscale up --accept-dns=false
  services.tailscale.enable = true;

  # Ensure tailscaled starts on boot with network ready
  systemd.services.tailscaled = {
    after = ["network-online.target"];
    wants = ["network-online.target"];
  };

  # Serve the NAS web portal (pdf./photos./media.frieren.lan vhosts on
  # nginx :80) and the 192.168.3.0/24 LAN to tailnet clients. Off-LAN
  # devices resolve *.frieren.lan via the pi-hole (--dns=100.97.61.65 on
  # desktop-client/eisen) and route here as a subnet router. Requires a
  # one-time admin-console approval of the route. SNAT stays on so the
  # browser-hostile services (Jellyfin device discovery, Paperless mail
  # callbacks) see tailnet-sourced traffic. Applied via `tailscale set` at
  # boot — survives without re-auth, unlike extraUpFlags.
  # (useRoutingFeatures = "both" is inherited from desktop-client.nix.)
  #
  # mkForce: Frieren is the PRIMARY resolver for the fleet. A resolver must
  # NEVER accept tailnet DNS (--accept-dns=false); accepting the tailnet
  # nameserver override creates a recursive query loop through 10.99.0.53.
  services.tailscale.extraSetFlags = [
    "--accept-dns=false"
    "--ssh=true"
  ];
  # The advertised routes (`192.168.3.0/24` + the DNS /32) are composed by
  # net/dns/tailnet-address.nix from `advertiseRoutes`, so they cannot
  # drift from the address this host actually binds.

  # Disable systemd-resolved stub listener so Pi-hole FTL can bind port 53 exclusively,
  # and route *.frieren.lan queries to the local Pi-hole stack.
  # (services.resolved.extraConfig was removed upstream; use settings.Resolve)
  #
  # LLMNR off (HC-7): resolved's LLMNR responder is a fixed public listener on
  # UDP 5355 with no LAN consumer — Avahi covers mDNS/multicast discovery here
  # (services.avahi below) and the fleet resolves names via the Pi-hole stack.
  # Leaving it on put a listener the firewall had to hold back; disabling it
  # removes the listener instead of scoping it.
  services.resolved.settings.Resolve = {
    DNSStubListener = "no";
    LLMNR = false;
    Domains = ["~frieren.lan"];
  };

  # Point the host resolver at FTL instead of the router:
  # /etc/resolv.conf -> systemd-resolved (uplink mode, stub off) -> FTL (127.0.0.1:53)
  # -> unbound (127.0.0.1#5335). NetworkManager used to inject the router
  # (192.168.3.1) from DHCP as resolved's per-link upstream, which leaked into
  # /etc/resolv.conf; dns="none" stops NM managing DNS and the global upstream
  # below routes resolved (and thus the host) through the local filtering stack.
  # mkForce: nixpkgs' resolved module defaults this to "systemd-resolved".
  networking.networkmanager.dns = lib.mkForce "none";
  networking.nameservers = [
    "127.0.0.1"
    "::1"
  ];

  # pihole-ftl references tailscale0 interface, must wait for tailscaled.
  # Restart=always: the resolver is the one unit whose death every client feels,
  # so a crash recovers itself instead of waiting for a human to notice.
  systemd.services.pihole-ftl = {
    after = ["tailscaled.service"];
    unitConfig = {
      X-Fleet-Role = "daemon";
      StartLimitIntervalSec = 0;
    };
    serviceConfig.Restart = lib.mkDefault "always";
    # Measured 2026-10-28: 13 threads × glibc's 64 MiB per-arena heap = 2.1 GB of
    # address space in 12 heaps, 934 MB of it swapped out, for a resolver whose
    # live set is ~840 MB (2.6 M queries FTL imports into memory at startup —
    # `database.DBimport = false` and `maxDBdays = 1` are both ignored by 6.7.1,
    # tested via a bind-mounted config). Two arenas put the peak at 1.10 GB and
    # swap at zero; MemoryHigh is the guard against a future FTL outgrowing it.
    environment.MALLOC_ARENA_MAX = "2";
    serviceConfig.MemoryHigh = "1200M";
  };

  # --- eval-time guards for the resolver --------------------------------------
  # The resolver is the fleet's single point of failure, so what makes it
  # survivable is asserted rather than remembered: the tailnet zone must be
  # forwarded (without it, every *.ts.net URL is NXDOMAIN for anyone using this
  # resolver — measured 2026-10-26). A local self-healing watchdog used to be
  # asserted here too; it was removed 2026-10-28 — minyx now answers as the
  # backup resolver, so a dead pihole degrades DNS instead of taking it away,
  # and the loop cost a full core to prove what the peer already covers.
  assertions = [
    {
      assertion =
        builtins.any (
          l: builtins.match "server=.*cloudforest-kardashev\\.ts\\.net.*" l != null
        )
        config.profiles.dnsFailover.extraDnsmasqLines;
      message = "dns: extraDnsmasqLines must forward the tailnet zone to MagicDNS (server=/cloudforest-kardashev.ts.net/100.100.100.100), or tailnet FQDNs resolve nowhere on the LAN.";
    }
  ];

  systemd.services.pihole-ftl-setup = {
    after = [
      "tailscaled.service"
      "pihole-ftl.service"
    ];
    wants = ["pihole-ftl.service"];
  };

  # Upstream's deleter (nixpkgs pihole-ftl.nix) is replaced because three
  # things in it keep retention from meaning "7 days":
  #
  # 1. `date('now','-7 day')` is a *calendar* day in UTC, and the timer fires at
  #    00:00 local. One run a day against a midnight cutoff leaves rows aged
  #    7-8 days — measured 2026-10-28 the oldest row sat exactly on the previous
  #    run's cutoff, 8.77 days old. Retention is now `now - 604800` (a rolling
  #    window) and the timer runs hourly, so the overshoot is an hour, not a day.
  # 2. Its `ConditionFileNotEmpty` is set in [Service], where systemd ignores it
  #    (journal: "Unknown key ... ignoring"), so the guard against creating an
  #    empty database never worked. The check is in the script instead.
  # 3. Deleting rows does not shrink the file: SQLite keeps the freed pages for
  #    reuse and FTL's insert rate consumes them, so the file holds its
  #    high-water mark (measured: 603 MB across 147k pages, freelist 0). VACUUM
  #    takes an exclusive lock and rewrites every page, so it is not worth a
  #    nightly run — it fires only when the freelist is already large (a mass
  #    delete), which is precisely when reclaiming matters.
  systemd.services.pihole-ftl-log-deleter = {
    serviceConfig.ExecStart = lib.mkForce (
      pkgs.writeShellScript "pihole-ftl-log-delete" ''
        set -u
        db='${config.services.pihole-ftl.settings.files.database}'
        sql='${lib.getExe config.services.pihole-ftl.package}'
        [ -s "$db" ] || { echo "$db absent or empty — nothing to delete"; exit 0; }

        echo "Deleting query logs older than 7 days (rolling window)"
        "$sql" sqlite3 "$db" \
          "PRAGMA busy_timeout=60000; DELETE FROM query_storage WHERE timestamp <= CAST(strftime('%s','now') AS INT) - 604800; SELECT changes() FROM query_storage LIMIT 1;"

        free=$("$sql" sqlite3 "$db" "PRAGMA freelist_count;")
        if [ "''${free:-0}" -gt 4096 ]; then
          echo "reclaiming $free free pages ($(( free * 4096 / 1024 / 1024 )) MiB) with VACUUM"
          "$sql" sqlite3 "$db" "PRAGMA busy_timeout=60000; VACUUM;" || echo "VACUUM deferred (database busy)"
        else
          echo "''${free:-0} free pages — nothing to reclaim"
        fi
      ''
    );
  };

  # Host policy on top of the profile's resolver core: what to block and how
  # long to keep logs. The `settings` block (dns/database/dnsmasq_lines) is
  # owned by profiles.dnsFailover and must not be redefined here.
  services.pihole-ftl = {
    # Log containment: keep FTL.log lean and auto-purge old DB queries
    queryLogDeleter = {
      enable = true;
      # `age` only feeds the message string: the ExecStart above owns the window.
      age = 7;
      # Hourly, so a rolling 7-day cutoff is honoured within the hour. The run
      # itself is one indexed DELETE plus a freelist_count read, and does nothing
      # at all when there is nothing old to remove.
      interval = "hourly";
    };
    lists = [
      {
        url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts";
        description = "StevenBlack fake news, gambling, and porn blocklist";
      }
      {
        url = "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt";
        description = "Disconnect tracking blocklist";
      }
    ];
  };

  # Pi-hole admin UI. The bind stays loopback (HC-7); the LAN reaches it through
  # the `pihole.frieren.lan` vhost in reverse-proxy.nix, which is also the portal
  # card. FTL's `webserver.port` accepts an interface prefix, which is how the
  # bind is narrowed without a second listener. The UI itself cannot be turned
  # off while `lists` is non-empty: nixpkgs loads those blocklists through the
  # web API and asserts on `webserver.port = ""` plus lists.
  services.pihole-web = {
    enable = true;
    ports = ["127.0.0.1:8080"];
  };

  # Port 53 on enp1s0 comes from profiles.dnsFailover; 67/4011 are the host's PXE
  # proxyDHCP surface. tailscale0 is opened explicitly — the profile only opens
  # the LAN interface.
  networking.firewall.interfaces.enp1s0 = {
    allowedUDPPorts = [
      67 # DHCP-proxy replies to PXE clients (the router still owns leases)
      4011 # legacy BIOS ProxyDHCP
    ];
  };
  # Allow DNS queries from Tailscale network
  networking.firewall.interfaces.tailscale0 = {
    allowedUDPPorts = [53];
    allowedTCPPorts = [53];
  };
  # Allow DNS queries during failover on Wi-Fi and USB-C dock
  networking.firewall.interfaces.wlp2s0 = {
    allowedUDPPorts = [53];
    allowedTCPPorts = [53];
  };
  networking.firewall.interfaces.enp0s20f0u2u1i5 = {
    allowedUDPPorts = [53];
    allowedTCPPorts = [53];
  };
}
