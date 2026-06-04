# DEPRECATED: Incus/LXC container module — all code is commented out.
# microvm.nix (microvm-host.nix profile) is the lighter replacement.
# Still imported by base-desktop-environment.nix but produces zero config.
# Remove the import line from base-desktop-environment.nix when dropping this.
# Created: 2024   Deprecated: 2025

{ config,
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # incus
  ];

  # virtualisation.incus.enable = true;
  # networking.firewall.enable = true;
  # networking.firewall.trustedInterfaces = [ "incusbr0" ];
  # networking.firewall.interfaces.incusbr0.allowedTCPPorts = [ 53 67 ];
  # networking.firewall.interfaces.incusbr0.allowedUDPPorts = [ 53 67 ];
  # networking.nftables.enable = true;
}
