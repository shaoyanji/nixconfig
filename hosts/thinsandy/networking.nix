{
  config,
  pkgs,
  ...
}: {
  # --- Networking tools ---
  environment.systemPackages = with pkgs; [
    docker
    ethtool
    networkd-dispatcher
  ];

  # --- Docker ---
  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  # --- DNS / ad-blocking ---
  services.crab-hole.enable = true;
  services.crab-hole.settings = {
    blocklist = {
      allow_list = [];
      include_subdomains = true;
      lists = [
        "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts"
        "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt"
      ];
    };
    downstream = [
      {
        listen = "localhost";
        port = 53;
        protocol = "udp";
      }
    ];
    upstream = {
      name_servers = [
        {
          protocol = "tls";
          socket_addr = "[2606:4700:4700::1111]:853";
          tls_dns_name = "1dot1dot1dot1.cloudflare-dns.com";
          trust_nx_responses = false;
        }
        {
          protocol = "tls";
          socket_addr = "1.1.1.1:853";
          tls_dns_name = "1dot1dot1dot1.cloudflare-dns.com";
          trust_nx_responses = false;
        }
      ];
      options = {
        validate = false;
      };
    };
  };

  # --- Firewall ---
  networking.firewall.allowedTCPPorts = [
    8123  # HomeAssistant
    7351  # Stirling PDF
  ];

  networking.firewall.allowedUDPPorts = [
    53
  ];
}
