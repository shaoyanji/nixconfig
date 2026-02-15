{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common/minimal-desktop.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Use the GRUB 2 boot loader.
  #boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  #boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking.hostName = "thinsandy"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # services.unbound = {
  #   enable = true;
  #   settings = {
  #     server = {
  #       # When only using Unbound as DNS, make sure to replace 127.0.0.1 with your ip address
  #       # When using Unbound in combination with pi-hole or Adguard, leave 127.0.0.1, and point Adguard to 127.0.0.1:PORT
  #       interface = ["127.0.0.1"];
  #       port = 5335;
  #       access-control = ["127.0.0.1 allow"];
  #       # Based on recommended settings in https://docs.pi-hole.net/guides/dns/unbound/#configure-unbound
  #       harden-glue = true;
  #       harden-dnssec-stripped = true;
  #       use-caps-for-id = false;
  #       prefetch = true;
  #       edns-buffer-size = 1232;

  #       # Custom settings
  #       hide-identity = true;
  #       hide-version = true;
  #     };
  #     forward-zone = [
  #       # Example config with quad9
  #       {
  #         name = ".";
  #         forward-addr = [
  #           "9.9.9.9#dns.quad9.net"
  #           "149.112.112.112#dns.quad9.net"
  #         ];
  #         forward-tls-upstream = true; # Protected DNS
  #       }
  #     ];
  #   };
  # };
  # services.pihole-ftl.enable = true;
  # services.pihole-web.enable = true;
  # services.pihole-web.ports = ["80r" "443s"];

  services.ollama = {
    enable = true;
    # acceleration = "cuda";
    host = "0.0.0.0";
    openFirewall = true;
    loadModels = ["minimax-m2.5:cloud" "glm-5:cloud" "qwen3-coder-next:cloud"];
    # environmentVariables = {
    # OLLAMA_ORIGINS = "moz-extension://*,chrome-extension://*,safari-web-extension://*";
    # };
    # models = "/Volumes/data/ollama";
  };
  services.anki-sync-server = {
    enable = true;
    address = "0.0.0.0";
    openFirewall = true;
    users = [
      {
        username = "bob";
        password = "password";
      }
    ];
  };
  services.home-assistant = {
    enable = true;
    extraComponents = [
      # "no_ip"
      # "lidarr"
      # "sonarr"
      # "radarr"
      "jellyfin"
      "plex"
      "tailscale"
      "fritzbox"
      "pi_hole"
      # "philips_js"
      # "qrcode"
      # "youtube"
      "github"
      "immich"
      # "esphome"
      "met"
      "radio_browser"
    ];
    config = {
      default_config = {};
    };
  };
  services.stirling-pdf.enable = true;
  services.stirling-pdf.environment = {
    SERVER_HOST = "0.0.0.0";
    SERVER_PORT = 7351;
    INSTALL_BOOK_AND_ADVANCED_HTML_OPS = "true";
  };
  services.plex = {
    enable = true;
    openFirewall = true;
    user = "devji";
  };
  services.crab-hole.enable = true;
  services.crab-hole.settings = {
    #   api = {
    #     admin_key = "1234";
    #     listen = "127.0.0.1";
    #     port = 8080;
    #     show_doc = true;
    #   };
    blocklist = {
      allow_list = [
        # "file:///allowed.txt"
      ];
      include_subdomains = true;
      lists = [
        "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts"
        "https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt"
        # "file:///blocked.txt"
      ];
    };
    downstream = [
      {
        listen = "localhost";
        port = 53;
        #     port = 8080;
        protocol = "udp";
      }
      #     {
      #       certificate = "dns.example.com.crt";
      #       dns_hostname = "dns.example.com";
      #       key = "dns.example.com.key";
      #       listen = "[::]";
      #       port = 8055;
      #       protocol = "https";
      #       timeout_ms = 3000;
      #     }
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
  # 1. enable vaapi on OS-level
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "intel-ocl"
    ];
  nixpkgs.config.packageOverrides = pkgs: {
    # Only set this if using intel-vaapi-driver
    intel-vaapi-driver = pkgs.intel-vaapi-driver.override {enableHybridCodec = true;};
  };
  users.users.immich.extraGroups = ["video" "render"];
  services = {
    # nginx.virtualHosts."nixos.servebeer.com" = {
    #   enableACME = true;
    #   forceSSL = true;
    #   locations."/" = {
    #     proxyPass = "http://[::1]:${toString config.services.immich.port}";
    #     proxyWebsockets = true;
    #     recommendedProxySettings = true;
    #     extraConfig = ''
    #       client_max_body_size 50000M;
    #       proxy_read_timeout   600s;
    #       proxy_send_timeout   600s;
    #       send_timeout         600s;
    #     '';
    #   };
    # };
    immich = {
      host = "0.0.0.0";
      enable = true;
      port = 2283;
      accelerationDevices = null;
      openFirewall = true;
    };
    sonarr = {
      enable = true;
      openFirewall = true;
    };

    readarr = {
      enable = true;
      openFirewall = true;
    };
    # transmission = {
    #   enable = true; #Enable transmission daemon

    #   package = pkgs.transmission_4;
    #   openRPCPort = true; #Open firewall for RPC
    #   settings = {
    #     #Override default settings
    #     rpc-bind-address = "0.0.0.0"; #Bind to own IP
    #     rpc-whitelist = "127.0.0.1,100.66.146.18,100.80.205.35,100.107.85.117,100.76.219.97,100.80.247.12,100.89.170.84,100.120.134.106";
    #     download-dir = "/Volumes/data/arr";
    #     # download-dir = "${config.services.transmission.home}/Downloads";
    #   };
    # };
    lidarr = {
      enable = true;
      openFirewall = true;
    };

    prowlarr = {
      enable = true;
      openFirewall = true;
    };

    radarr = {
      enable = true;
      openFirewall = true;
    };
  };
  systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "iHD"; # Or "i965" if using older driver
  environment.sessionVariables = {LIBVA_DRIVER_NAME = "iHD";}; # Same here
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # For Broadwell (2014) or newer processors. LIBVA_DRIVER_NAME=iHD
      # intel-vaapi-driver # For older processors. LIBVA_DRIVER_NAME=i965
      libva-vdpau-driver # Previously vaapiVdpau
      # intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
      # OpenCL support for intel CPUs before 12th gen
      # see: https://github.com/NixOS/nixpkgs/issues/356535
      intel-compute-runtime-legacy1
      vpl-gpu-rt # QSV on 11th gen or newer
      # intel-media-sdk # QSV up to 11th gen #security
      intel-ocl # OpenCL support
    ];
  };
  # 2. do not forget to enable jellyfin
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };
  environment.systemPackages = with pkgs; [
    opencode
    ollama
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
    go
    btrfs-progs
    f2fs-tools
    docker
    ethtool
    networkd-dispatcher
    powertop
  ];

  powerManagement.powertop.enable = true;
  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
    daemon.settings = {
      # data-root = "/some-place/to-store-the-docker-data";
    };
  };
  #  services.k3s = {
  #    enable = true;
  #    role = "server";
  #    tokenFile = "${config.sops.secrets."local/k3s/token".path}";
  #    clusterInit = true;
  #  };
  networking.firewall.allowedTCPPorts = [
    8123 #HomeAssistant
    7351 #Stirling PDF
    #    6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
    #    #    2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
    #    #    2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
  ];

  networking.firewall.allowedUDPPorts = [
    #    8472 # k3s, flannel: required if using multi-node for inter-node networking
    53
  ];
  system.stateVersion = "25.05"; # Did you read the comment?
}
