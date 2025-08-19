{
  config,
  lib,
  ...
}: {
  specialisation = {
    server.configuration = {
      #  services = {
      #    networkd-dispatcher = {
      #      enable = true;
      #      rules."50-tailscale" = {
      #        onState = ["routable"];
      #        script = ''
      #          ${lib.getExe pkgs.ethtool} -K eth0 rx-udp-gro-forwarding on rx-gro-list off
      #        '';
      #      };
      #    };
      #  };

      #  services.blocky = {
      #    enable = true;
      #
      #    settings = {
      #      ports.dns = 53; # Port for incoming DNS Queries.
      #      upstreams.groups.default = [
      #        "https://one.one.one.one/dns-query" # Using Cloudflare's DNS over HTTPS server for resolving queries.
      #      ];
      #      # For initially solving DoH/DoT Requests when no system Resolver is available.
      #      bootstrapDns = {
      #        upstream = "https://one.one.one.one/dns-query";
      #        ips = ["1.1.1.1" "1.0.0.1"];
      #      };
      #      #Enable Blocking of certain domains.
      #      blocking = {
      #        denylists = {
      #          #Adblocking
      #          ads = ["https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"];
      #          #Another filter for blocking adult sites
      #          #adult = ["https://blocklistproject.github.io/Lists/porn.txt"];
      #          #You can add additional categories
      #        };
      #        #Configure what block categories are used
      #        clientGroupsBlock = {
      #          default = ["ads"];
      #          #kids-ipad = ["ads" "adult"];
      #        };
      #      }; # anything from config.yml
      #      conditional = {
      #        fallbackUpstream = false;
      #        rewrite = {
      #          bountystash.com = "fritz.box";
      #        };
      #        mapping = {
      #          fritz.box = "192.168.178.1";
      #        };
      #      };
      #    };
      #  };
      #  networking.nftables.enable = true;
      #  services.resolved = {
      #    enable = true;
      #    dnssec = "true";
      #    domains = ["~."];
      #    fallbackDns = [
      #      "192.168.178.1"
      #    ];
      #    dnsovertls = "true";
      #  };
      powerManagement.powertop.enable = true;
      system.nixos.tags = ["server"];
      services.tailscale = {
        enable = true;
        useRoutingFeatures = lib.mkForce "server";
      };
      networking = {
        firewall = {
          trustedInterfaces = ["tailscale0"];
          allowedTCPPorts = [22];
          interfaces.tailscale0.allowedUDPPorts = [config.services.tailscale.port];
        };
        nameservers = lib.mkDefault ["100.100.100.100"];
        search = lib.mkDefault ["cloudforest-kardashev.ts.net"];
      };
    };
  };
}
