{
  pkgs,
  lib,
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

  # --- Stirling PDF (re-enabled 2026-09-29) ---
  # Port 7351 because the module default 8080 collides with pihole-web.
  # Opened here (not in configuration.nix's firewall block) so the
  # port lives next to the service that needs it.
  services.stirling-pdf = {
    enable = true;
    environment = {
      SERVER_PORT = "7351";
      SECURITY_ENABLELOGIN = "false";
    };
  };
  networking.firewall.allowedTCPPorts = lib.mkAfter [7351];

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
