# Firewall scoping: every open service port is reachable ONLY on the LAN
# NICs (enp1s0 wired, wlp2s0 wifi) and tailscale0 — not from docker0, a
# container bridge, or any interface that appears later.
#
# Why: NixOS's global `allowedTCPPorts`/`allowedUDPPorts` accepts are
# interface-blind (live: `-A nixos-fw -p tcp --dport 22 -j nixos-fw-accept`),
# so they also accept docker0 and anything else. This module empties the
# global lists (mkForce) and re-applies the SAME ports per interface via
# `networking.firewall.interfaces` (the pattern dns.nix already uses for
# DNS/DHCP-proxy).
#
# FAILOUD RULE: the global lists still receive every module's contributions
# (configuration.nix, reverse-proxy, iventoy, ha-stack, infra-stack,
# networking.nix, `openFirewall = true` services, …) but they are overridden
# here — a port that is only added to a global list stays CLOSED everywhere
# (the service breaks loudly) until it is also added to the explicit lists
# below. Auto-derivation from the option's `.definitions` was evaluated and
# rejected: `.definitions` only keeps the winning (forced) definition, so
# contributors cannot be read back after mkForce. Keep the two lists below
# in sync when opening new ports.
#
# Unaffected: lo + established/related replies (unconditional rules at the
# top of nixos-fw), ICMP/allowPing, and dns.nix's extra per-interface
# entries (they merge in additively). The chain's final refuse still drops
# everything else — including NEW connections from docker0, which is the
# point.
{lib, ...}: let
  scopedIfaces = [
    "enp1s0" # wired LAN
    "wlp2s0" # wifi LAN
    "tailscale0"
  ];

  # Keep in sync with the global contributions (see FAILOUD RULE above).
  # Source of truth for provenance: the per-service blocks that declare
  # them (grep `allowedTCPPorts` / `openFirewall` across hosts/frieren/).
  scopedTCP = [
    22 # sshd
    80 # nginx vhosts (reverse-proxy.nix)
    139
    445 # samba (configuration.nix)
    631 # cups
    2049 # nfs
    2283 # immich
    3001 # uptime-kuma (ha-stack.nix)
    3005
    5000 # harmonia LAN cache (modules/services/harmonia.nix)
    5357
    6801 # AriaNg (configuration.nix)
    7351 # Stirling PDF (networking.nix)
    7878
    8088 # kiwix-serve (kiwix.nix, openFirewall)
    8096 # jellyfin
    8123 # Home Assistant (configuration.nix)
    8124 # scrutiny (infra-stack.nix)
    8324
    8686
    8787
    8920
    8989
    9696
    16000 # iVentoy HTTP PXE (iventoy.nix)
    26000
    27701
    28981 # paperless-ngx (configuration.nix)
    32400
    32469
  ];

  scopedUDP = [
    67
    69 # dnsmasq/PXE (iventoy.nix, dns.nix)
    137
    138 # samba netbios (configuration.nix)
    1900 # ssdp
    3702 # ws-discovery
    4011 # legacy BIOS ProxyDHCP (iventoy.nix)
    5353 # avahi/mDNS
    7359
    32410
    32412
    32413
    32414 # samsung/airplay-ish casts
  ];
in {
  networking.firewall = {
    allowedTCPPorts = lib.mkForce [];
    allowedUDPPorts = lib.mkForce [];
    interfaces = lib.genAttrs scopedIfaces (_: {
      allowedTCPPorts = scopedTCP;
      allowedUDPPorts = scopedUDP;
    });
  };
}
