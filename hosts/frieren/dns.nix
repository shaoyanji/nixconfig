_: {
  # Tailnet DNS should stay manually managed after deployment:
  # sudo tailscale up --accept-dns=false
  services.tailscale.enable = true;

  # Ensure tailscaled starts on boot with network ready
  systemd.services.tailscaled = {
    after = ["network-online.target"];
    wants = ["network-online.target"];
  };

  # pihole-ftl references tailscale0 interface, must wait for tailscaled
  systemd.services.pihole-ftl = {
    after = ["tailscaled.service"];
  };
  systemd.services.pihole-ftl-setup = {
    after = ["tailscaled.service"];
  };

  services.unbound = {
    enable = true;
    resolveLocalQueries = false;
    settings.server = {
      interface = ["127.0.0.1@5335"];
      access-control = ["127.0.0.0/8 allow"];
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
        upstreams = ["127.0.0.1#5335"];
        # listeningMode = "LOCAL";
        listeningMode = "ALL";
        interface = "enp1s0";
      };
      database = {
        maxDBdays = 31;
      };
      misc.dnsmasq_lines = ["interface=tailscale0"];
      # webserver.api.cli_pw = true;
    };
  };

  services.pihole-web = {
    enable = true;
    ports = [8080];
  };
  networking.firewall.interfaces.enp1s0 = {
    allowedUDPPorts = [53];
    allowedTCPPorts = [53];
  };
  # Allow DNS queries from Tailscale network
  networking.firewall.interfaces.tailscale0 = {
    allowedUDPPorts = [53];
    allowedTCPPorts = [53];
  };
}
