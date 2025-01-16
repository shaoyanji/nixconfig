{inputs, config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nvidia.nix
      ../common/steam.nix
      ../base-desktop-environment.nix
      # ../cifs.nix
    ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
    networking.hostName = "poseidon"; # Define your hostname.
  environment.systemPackages = with pkgs; [
  ];
  environment.variables = {

  };
  system.stateVersion = "24.05"; # Did you read the comment?
}
