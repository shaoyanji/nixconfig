{...}: {
  # Tailnet DNS should stay manually managed after deployment:
  # sudo tailscale up --accept-dns=false
  services.tailscale.enable = true;

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
        upstreams = ["127.0.0.1#5335"];
        # listeningMode = "LOCAL";
        listeningMode = "ALL";
        interface = "eno1";
      };
      # misc.dnsmasq_lines = ["interface=tailscale0"];
      # webserver.api.cli_pw = true;
    };
  };

  services.pihole-web = {
    enable = true;
    ports = [8080];
  };
  networking.firewall.interfaces.eno1 = {
    allowedUDPPorts = [53];
    allowedTCPPorts = [53];
  };
}
