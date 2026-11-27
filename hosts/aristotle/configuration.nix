{
  self,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    self.modules."profiles.base-desktop-environment"
    self.modules."profiles.laptop"
    self.modules."profiles.haswell-graphics"
    self.modules."profiles.dns-client"
  ];

  boot.supportedFilesystems = ["nfs"];
  profiles.nasClient.extraOptions = ["nfsvers=4" "soft" "rw" "intr"];

  # Inbound ICMP ping allowed for diagnostics and network health audits
  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [2049];

  # Host-specific diagnostic tools
  environment.systemPackages = with pkgs; [
    dmidecode
  ];

  # Tailscale: disable accepting subnet routes on Aristotle to preserve native LAN routing
  # (prevents table 52 from hijacking direct LAN traffic and causing asymmetric routing drops, matching fern and eisen)
  # The xs-notify toaster was rewritten to a Telegram lane on delphi
  # (ea0e6766): this host's toast flag went with it.

  fleet.tailscale.acceptRoutes = false;

  # profiles.dnsClient, above: VIP first, tailnet second, public fallback last.
  # NetworkManager accepts DHCP DNS on all connections (Wi-Fi, ethernet) so public Wi-Fi /
  # captive portals work normally without getting trapped on unroutable private nameservers.
  profiles.dnsClient.enable = true;

  system.stateVersion = "26.05";
}
