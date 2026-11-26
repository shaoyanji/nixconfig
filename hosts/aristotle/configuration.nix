{
  self,
  lib,
  pkgs,
  user,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    self.modules."profiles.base-desktop-environment"
    self.modules."profiles.laptop"
    self.modules."profiles.dns-client"
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

  # Host-specific diagnostic tools
  environment.systemPackages = with pkgs; [
    libva-utils
    dmidecode
  ];

  # Tailscale: disable accepting subnet routes on Aristotle to preserve native LAN routing
  # (prevents table 52 from hijacking direct LAN traffic and causing asymmetric routing drops, matching fern and eisen)
  # The xs-notify toaster was rewritten to a Telegram lane on delphi
  # (ea0e6766): this host's toast flag went with it.

  services.tailscale.extraSetFlags = lib.mkForce [
    "--accept-dns=true"
    "--accept-routes=false"
  ];

  # profiles.dnsClient, above: VIP first, tailnet second, public fallback last.
  # NetworkManager accepts DHCP DNS on all connections (Wi-Fi, ethernet) so public Wi-Fi /
  # captive portals work normally without getting trapped on unroutable private nameservers.
  profiles.dnsClient.enable = true;

  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home;
  };

  system.stateVersion = "26.05";
}
