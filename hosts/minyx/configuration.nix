# minyx — host entry.
#
# The bootloader and firmware are owned by the sd-image module imported from
# hardware-configuration.nix, so no loader is configured by hand here.
{...}: {
  imports = [
    ./hardware-configuration.nix
    ./custompi.nix
    ./dns.nix
    ./tunnel.nix
  ];

  # base-node.nix sets this for the fleet, and this host does not import it. Left
  # as UTC, its journal is an hour off every other host's: during the 2026-10-27
  # failover test a BACKUP transition and the matching MASTER transition on
  # frieren could not be lined up without converting by hand.
  time.timeZone = "Europe/Berlin";

  system.stateVersion = "24.11";
}
