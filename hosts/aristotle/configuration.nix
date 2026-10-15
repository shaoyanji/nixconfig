{lib, ...}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/profiles/base-desktop-environment.nix
    ../../modules/profiles/laptop.nix
  ];

  boot.supportedFilesystems = ["nfs"];
  ssh.ca.enableClient = true;

  fileSystems."/Volumes/data" = {
    device = "192.168.3.25:/data";
    fsType = "nfs";
    options = ["nfsvers=4" "soft" "rw" "intr"];
  };

  networking.firewall.allowedTCPPorts = [2049];
  networking.hostName = "aristotle";

  # Declarative Fleet DNS: Pi-hole on frieren (192.168.3.25 LAN / 100.97.61.65 Tailscale)
  # Lock NetworkManager defaults so all connection profiles (Ethernet & Wi-Fi) automatically
  # ignore router DHCP DNS (192.168.3.1) and route queries to the fleet Pi-hole.
  networking.networkmanager.connectionConfig = {
    "ipv4.dns" = "192.168.3.25;100.97.61.65;";
    "ipv4.ignore-auto-dns" = true;
    "ipv6.ignore-auto-dns" = true;
    "ipv4.dns-search" = "lan;frieren.lan;cloudforest-kardashev.ts.net;";
  };
  networking.nameservers = ["192.168.3.25" "100.97.61.65"];
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = "192.168.3.25 100.97.61.65";
      FallbackDNS = "1.1.1.1 8.8.8.8";
      Domains = ["~lan" "~frieren.lan" "~.cloudforest-kardashev.ts.net" "~."];
    };
  };

  services.displayManager.sddm = {
    enable = false;
    wayland.enable = true;
  };

  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home;
  };

  system.stateVersion = "26.05";
}
