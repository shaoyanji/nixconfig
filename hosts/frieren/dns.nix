{ config
, lib
, pkgs
, ...
}: {
  # Tailnet DNS should stay manually managed after deployment:
  # sudo tailscale up --accept-dns=false
  services.tailscale.enable = true;

  # Ensure tailscaled starts on boot with network ready
  systemd.services.tailscaled = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
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
    "--advertise-routes=192.168.3.0/24"
  ];

  # Disable systemd-resolved stub listener so Pi-hole FTL can bind port 53 exclusively,
  # and route *.frieren.lan queries to the local Pi-hole stack.
  # (services.resolved.extraConfig was removed upstream; use settings.Resolve)
  services.resolved.settings.Resolve = {
    DNSStubListener = "no";
    Domains = [ "~frieren.lan" ];
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
    after = [ "tailscaled.service" ];
  };
  systemd.services.pihole-ftl-setup = {
    after = [
      "tailscaled.service"
      "pihole-ftl.service"
    ];
    wants = [ "pihole-ftl.service" ];
  };

  # Work around upstream nixpkgs pihole-ftl queryLogDeleter systemd %s specifier expansion bug:
  # Systemd expands '%s' to the user's shell (/run/current-system/sw/bin/bash).
  # Use '%%s' so systemd passes a literal '%s' to sqlite3.
  systemd.services.pihole-ftl-log-deleter = {
    serviceConfig.ExecStart = lib.mkForce [
      "${pkgs.coreutils}/bin/echo 'Deleting query logs older than 7 days'"
      "${config.services.pihole-ftl.package}/bin/pihole-FTL sqlite3 '${config.services.pihole-ftl.settings.files.database}' 'DELETE FROM query_storage WHERE timestamp <= CAST(strftime('%%s', date('now', '-7 day')) AS INT); select changes() from query_storage limit 1'"
    ];
  };

  services.unbound = {
    enable = true;
    resolveLocalQueries = false;
    settings.server = {
      interface = [ "127.0.0.1@5335" ];
      access-control = [ "127.0.0.0/8 allow" ];
    };
  };

  services.pihole-ftl = {
    enable = true;
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
    settings = {
      dns = {
        queryLogging = true;
        upstreams = [ "127.0.0.1#5335" ];
        # listeningMode = "LOCAL";
        listeningMode = "ALL";
        interface = "enp1s0";
      };
      database = {
        maxDBdays = 31;
      };
      misc.dnsmasq_lines = [
        "interface=tailscale0"
        "address=/frieren.lan/192.168.3.25"
        # eisen's local LLM API (llama.cpp OpenAI /v1) resolves to its stable
        # tailnet address; LAN clients reach it over the tailnet.
        "address=/eisen.lan/100.119.172.99"
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
      # webserver.api.cli_pw = true;
    };
  };

  services.pihole-web = {
    enable = true;
    ports = [ 8080 ];
  };
  networking.firewall.interfaces.enp1s0 = {
    allowedUDPPorts = [
      53
      67 # DHCP-proxy replies to PXE clients (FritzBox still owns leases)
      4011 # legacy BIOS ProxyDHCP
    ];
    allowedTCPPorts = [ 53 ];
  };
  # Allow DNS queries from Tailscale network
  networking.firewall.interfaces.tailscale0 = {
    allowedUDPPorts = [ 53 ];
    allowedTCPPorts = [ 53 ];
  };
}
