# Firewall scoping: every open service port is reachable ONLY on the LAN NICs
# (enp1s0 wired, wlp2s0 wifi) and tailscale0 — not from docker0, a container
# bridge, or any interface that appears later.
#
# Why: NixOS's global `allowedTCPPorts`/`allowedUDPPorts` accepts are
# interface-blind (live: `-A nixos-fw -p tcp --dport 22 -j nixos-fw-accept`),
# so they also accept docker0 and anything else. This module empties the
# global lists (mkForce) and re-applies the ports per interface.
#
# The per-interface lists are derived by
# `modules/profiles/service-exposure.nix` from the `profiles.serviceExposure`
# registry below, so a service's exposure is declared once. `dns.nix` still
# adds its own per-interface entries (53/67/4011) additively — the merge is
# intentional, and `task checks:ports` remains the drift guard.
#
# FAIL-CLOSED RULE: the mkForce on the global lists is absolute, so a port that
# only reaches the globals (a service's `openFirewall = true`) stays CLOSED
# everywhere on this host until it is declared in the registry below. Migrate a
# service by adding its port here, not by removing the mkForce.
#
# Unaffected: lo + established/related replies (unconditional rules at the top
# of nixos-fw), ICMP/allowPing, and dns.nix's per-interface entries (they merge
# in additively). The chain's final refuse still drops everything else —
# including NEW connections from docker0, which is the point.
{lib, ...}: let
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
        port = 2283;
        proxy = {
          name = "photos.frieren.lan";
          websockets = true;
        };
      };
      uptime-kuma = {
        port = 3001;
        proxy = {
          name = "status.frieren.lan";
          websockets = true;
        };
      };
      harmonia = {
        port = 5000;
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
      stirling-pdf = {
        port = 7351;
        proxy = {
          name = "pdf.frieren.lan";
          websockets = true;
        };
      };
      tcp-7878 = {port = 7878;};
      kiwix = {
        port = 8088;
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
        port = 8123;
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
