# Firewall scoping: every open service port is reachable ONLY on the LAN NICs
{
  config,
  lib,
  ...
}: let
  scopedIfaces = [
    "enp1s0" # wired LAN
    "enp0s20f0u2u1i5" # USB-C dock wired LAN
    "wlp2s0" # wifi LAN
    "tailscale0"
  ];
in {
  imports = [../../modules/profiles/service-exposure.nix];

  # Every port frieren exposes on the scoped interfaces, declared once. Keys
  # are named after the owning service where known; `tcp-<port>`/`udp-<port>`
  # are ports whose owner is not recorded anywhere in the tree (kept verbatim
  # from the previous hand-written list so no exposure changed).
  #
  # Pruned 2026-10-12 (HC-7) — `task checks:ports` reported these as DEAD-HOLE
  # (declared, no listener): 631 (CUPS, removed by the Tier-1 debloat), 3005,
  # 8324 and 8920 (no owning service anywhere in the tree; 8920 is Jellyfin's
  # HTTPS port, which this host does not serve), and 32469 (Plex DLNA, off).
  # Port values are read from the option that owns them wherever one exists, so
  # moving a service port cannot leave a stale hole (or a stale closed port)
  # behind in the scoped lists.
  profiles.serviceExposure = {
    enable = true;
    interfaces = scopedIfaces;
    services = {
      ssh = {port = 22;};
      nginx = {port = 80;};
      nginx-https = {port = 443;};
      samba-netbios-ssn = {port = 139;};
      samba-smb = {port = 445;};
      # 631 (CUPS) pruned 2026-10-12 — nothing has listened on it since the
      # Tier-1 printing debloat; it was a hole with no service behind it.
      nfs = {port = 2049;};
      immich = {
        port = config.services.immich.port;
        proxy = {
          name = "photos.frieren.lan";
          websockets = true;
        };
      };
      uptime-kuma = {
        port = config.services.ha-stack.uptime-kuma.port;
        proxy = {
          name = "status.frieren.lan";
          websockets = true;
        };
      };
      harmonia = {
        port = config.services.harmonia-fleet.port;
        proxy = {
          name = "cache.frieren.lan";
        };
      };
      simplex-smp = {port = 5223;};
      tcp-5357 = {port = 5357;};
      ariang = {
        port = 6801;
        proxy = {
          name = "aria.frieren.lan";
          websockets = true;
        };
      };
      # stirling-pdf moved to delphi (tailnet 8445); `pdf.frieren.lan` is gone
      # with it, so the bookmark is now the ts.net name — see
      # `open-frieren-offload` in AGENTS.nix.
      tcp-7878 = {port = 7878;};
      kiwix = {
        port = config.services.kiwix-serve.port;
        proxy = {
          name = "wiki.frieren.lan";
        };
      };
      jellyfin = {
        port = 8096;
        proxy = {
          name = "media.frieren.lan";
          websockets = true;
        };
      };
      home-assistant = {
        port = config.services.ha-stack.port;
        proxy = {
          name = "ha.frieren.lan";
          websockets = true;
        };
      };
      scrutiny = {
        port = 8124;
        proxy = {
          name = "smart.frieren.lan";
        };
      };
      tcp-8686 = {port = 8686;};
      tcp-8787 = {port = 8787;};
      tcp-8989 = {port = 8989;};
      tcp-9696 = {port = 9696;};
      iventoy-http = {port = 16000;};
      tcp-26000 = {port = 26000;};
      tcp-27701 = {port = 27701;};
      paperless = {
        port = 28981;
        proxy = {
          name = "docs.frieren.lan";
          websockets = true;
        };
      };
      plex = {port = 32400;};
      # 32469 (Plex DLNA) pruned 2026-10-12 — Plex's DLNA plugin is not
      # enabled, so the port had no listener.

      dnsmasq-pxe = {
        port = 67;
        tcp = false;
        udp = true;
      };
      tftp = {
        port = 69;
        tcp = false;
        udp = true;
      };
      samba-netbios-ns = {
        port = 137;
        tcp = false;
        udp = true;
      };
      samba-netbios-dgm = {
        port = 138;
        tcp = false;
        udp = true;
      };
      ssdp = {
        port = 1900;
        tcp = false;
        udp = true;
      };
      ws-discovery = {
        port = 3702;
        tcp = false;
        udp = true;
      };
      proxydhcp = {
        port = 4011;
        tcp = false;
        udp = true;
      };
      mdns = {
        port = 5353;
        tcp = false;
        udp = true;
      };
      udp-7359 = {
        port = 7359;
        tcp = false;
        udp = true;
      };
      cast-32410 = {
        port = 32410;
        tcp = false;
        udp = true;
      };
      cast-32412 = {
        port = 32412;
        tcp = false;
        udp = true;
      };
      cast-32413 = {
        port = 32413;
        tcp = false;
        udp = true;
      };
      cast-32414 = {
        port = 32414;
        tcp = false;
        udp = true;
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = lib.mkForce [];
    allowedUDPPorts = lib.mkForce [];
  };
}
