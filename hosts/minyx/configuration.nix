# minyx — host entry.
#
# The bootloader and firmware are owned by the sd-image module imported from
# hardware-configuration.nix, so no loader is configured by hand here.
{...}: {
  imports = [
    ./hardware-configuration.nix
    ./custompi.nix
    ./tunnel.nix
  ];

  system.stateVersion = "24.11";
}
