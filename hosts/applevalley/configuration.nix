{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/profiles/desktop-client.nix
    ../../modules/profiles/laptop.nix
  ];
  networking.hostName = "applevalley";
  environment.systemPackages = with pkgs; [
    btrfs-progs
  ];

  system.stateVersion = "24.11";
}
