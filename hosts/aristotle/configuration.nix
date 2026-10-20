{
  lib,
  pkgs,
  ...
}: let
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

  # Inbound ICMP ping allowed for diagnostics and network health audits
  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [2049];

  # Hardware video acceleration for Intel HD Graphics 4400 (Haswell Gen 7.5).
  # Uses legacy i965 intel-vaapi-driver (modern intel-media-driver iHD only supports Gen 8+ / Broadwell+).
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
      libvdpau-va-gl
    ];
  };
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "i965";
  };

  # Tailscale: disable accepting subnet routes on Aristotle to preserve native LAN routing
  # (prevents table 52 from hijacking direct LAN traffic and causing asymmetric routing drops, matching fern and eisen)
  services.tailscale.extraSetFlags = lib.mkForce [
    "--accept-dns=true"
    "--accept-routes=false"
  ];

  # Declarative Fleet DNS: Pi-hole on frieren (192.168.3.25 LAN / 100.97.61.65 Tailscale)
  # Scoped specifically to ~lan and ~frieren.lan routing domains.
  # NetworkManager accepts DHCP DNS on all connections (Wi-Fi, ethernet) so public Wi-Fi /
  # captive portals work normally without getting trapped on unroutable private nameservers.
  networking.nameservers = ["192.168.3.25" "100.97.61.65"];
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = "192.168.3.25 100.97.61.65";
      FallbackDNS = "1.1.1.1 8.8.8.8";
      Domains = ["~lan" "~frieren.lan"];
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
