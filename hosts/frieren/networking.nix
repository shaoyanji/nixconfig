{pkgs, ...}: let
  # frieren's LAN identity used to live only in
  # /etc/NetworkManager/system-connections/Wired connection 1.nmconnection — an
  # imperative file with a random UUID that nothing in this repo declared. Every
  # other thing on this host assumes it exists: dns.nix hardcodes 192.168.3.25
  # as the zone address and opens 53 on enp1s0, the tailnet advertises
  # 192.168.3.0/24, and pihole-ftl binds the LAN interface. So the one fact the
  # resolver depends on was the one fact Nix did not own, and when the profile
  # was not applied (observed 2026-10-24: the router at .1 answered, .25 did
  # not, and the host was up the whole time) every client lost DNS with no
  # config to blame.
  #
  # Declared here instead: the same address, gateway and metric the imperative
  # profile carried, with a stable UUID, so a rebuild always restores it.
  lanProfile = {
    connection = {
      id = "frieren-lan";
      uuid = "6f1c9a52-8d3e-4a71-9c0b-2f7d5e14a903";
      type = "ethernet";
      interface-name = "enp1s0";
      autoconnect = "true";
      autoconnect-priority = "100";
    };
    ipv4 = {
      method = "manual";
      address1 = "192.168.3.25/24";
      gateway = "192.168.3.1";
      route-metric = "300";
      dns-search = "~lan;~frieren.lan;";
    };
    ipv6 = {
      method = "auto";
      addr-gen-mode = "default";
      route-metric = "300";
    };
  };
in {
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

  # --- Static LAN profile, owned by Nix ---
  networking.networkmanager.ensureProfiles.profiles.lan = lanProfile;

  # --- Stirling PDF: MOVED to delphi (2026-10-21) ---
  # It is stateless, so it was the one service worth moving off this host while
  # paperless and immich stay where their data and their users are. It now runs
  # on delphi behind `tailscale serve` (port 8445) — see
  # `.agents/deploy/hosts/delphi.md`, and AGENTS.nix `open-frieren-offload`.
  # Nothing here listens on 7351 any more, and the firewall does not open it.

  # --- Inbound LAN Failover (enp1s0 -> wlp2s0) ---
  # If the primary wired link drops, float 192.168.3.25 to Wi-Fi with gratuitous ARP.
  # When reconnected, restore 192.168.3.25 exclusively to enp1s0.
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "lan-failover" ''
        IFACE="''$1"
        ACTION="''$2"

        # Only react to link transitions on the primary wired interface (enp1s0)
        if [ "''$IFACE" != "enp1s0" ]; then
          exit 0
        fi

        case "''$ACTION" in
          down|pre-down)
            echo "[lan-failover] enp1s0 is down; promoting 192.168.3.25 to wlp2s0" | ${pkgs.systemd}/bin/systemd-cat -t lan-failover -p warning
            ${pkgs.iproute2}/bin/ip addr add 192.168.3.25/24 dev wlp2s0 label wlp2s0:vip 2>/dev/null || true
            ${pkgs.iputils}/bin/arping -c 3 -U -I wlp2s0 192.168.3.25 2>/dev/null || true
            ;;
          up)
            echo "[lan-failover] enp1s0 is up; restoring 192.168.3.25 to enp1s0" | ${pkgs.systemd}/bin/systemd-cat -t lan-failover -p notice
            ${pkgs.iproute2}/bin/ip addr del 192.168.3.25/24 dev wlp2s0 2>/dev/null || true
            ${pkgs.iputils}/bin/arping -c 3 -U -I enp1s0 192.168.3.25 2>/dev/null || true
            ;;
        esac
      '';
    }
  ];
}
