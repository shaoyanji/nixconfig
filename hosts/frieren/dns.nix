{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/profiles/dns-failover.nix
    ../../modules/profiles/tailnet-dns-address.nix
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
  # modules/profiles/dns-failover.nix. frieren is the fleet PRIMARY; host policy
  # (extra address= records, the tailscale interface line, PXE proxyDHCP,
  # blocklists, the web UI) stays here and is fed in.
  #
  # No `virtualIp` yet: failover is client-side via `resolvers` until a
  # floating address is worth the router/client change. fern runs the matching
  # `role = "secondary"` stack (hosts/fern/configuration.nix) with the same
  # zone/zoneAddress, so a client that falls back gets identical answers.
  #
  # fern's own address is deliberately NOT listed: it is DHCP, so it belongs in
  # the router's DHCP reservation (or a tailnet name), never as a literal here.
  # See docs/dns-failover.md for the failover test.
  profiles.dnsFailover = {
    enable = true;
    role = "primary";
    lanInterface = "enp1s0";
    zone = "frieren.lan";
    zoneAddress = "192.168.3.25";
    resolvers = ["192.168.3.25"];
    extraDnsmasqLines = [
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
      # --- PXE proxyDHCP for iVentoy (ExternalNet mode on :16000/:69) ---
      # Answer ONLY PXE clients on the LAN; never lease IPs — the FritzBox
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
  services.tailscale.extraSetFlags = [
    "--ssh=true"
  ];
  # The advertised routes (`192.168.3.0/24` + the DNS /32) are composed by
  # profiles/tailnet-dns-address.nix from `advertiseRoutes`, so they cannot
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

  # pihole-ftl references tailscale0 interface, must wait for tailscaled
  systemd.services.pihole-ftl = {
    after = ["tailscaled.service"];
  };
  systemd.services.pihole-ftl-setup = {
    after = [
      "tailscaled.service"
      "pihole-ftl.service"
    ];
    wants = ["pihole-ftl.service"];
  };

  # Work around upstream nixpkgs pihole-ftl queryLogDeleter systemd %s and quote escaping quirks:
  # Using writeShellScript ensures the SQL query is passed intact with proper quotes and without systemd specifier substitution.
  systemd.services.pihole-ftl-log-deleter = {
    serviceConfig.ExecStart = lib.mkForce (
      pkgs.writeShellScript "pihole-ftl-log-delete" ''
        echo "Deleting query logs older than 7 days"
        exec ${config.services.pihole-ftl.package}/bin/pihole-FTL sqlite3 "${config.services.pihole-ftl.settings.files.database}" \
          "DELETE FROM query_storage WHERE timestamp <= CAST(strftime('%s', date('now', '-7 day')) AS INT); SELECT changes() FROM query_storage LIMIT 1;"
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
      age = 7;
      interval = "daily";
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

  # Pi-hole admin UI. Bound to loopback (HC-7): the runbook's access path is a
  # port-forward (`ssh -L 8080:localhost:8080 frieren` → http://localhost:8080/admin,
  # docs/frieren-access.md), so the LAN hole on 8080 was never the intended way in.
  # FTL's `webserver.port` accepts an interface prefix, which is how the bind is
  # narrowed without a proxy.
  services.pihole-web = {
    enable = true;
    ports = ["127.0.0.1:8080"];
  };

  # Port 53 on enp1s0 comes from profiles.dnsFailover; 67/4011 are the host's PXE
  # proxyDHCP surface. tailscale0 is opened explicitly — the profile only opens
  # the LAN interface.
  networking.firewall.interfaces.enp1s0 = {
    allowedUDPPorts = [
      67 # DHCP-proxy replies to PXE clients (FritzBox still owns leases)
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
