{inputs, config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nvidia.nix
      ../common/steam.nix
      ../common/base-desktop-environment.nix
    ];
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_cachyos;
  networking.hostName = "poseidon"; # Define your hostname.
  #environment={
  #systemPackages = with pkgs; [
  #];
  #variables = {
  # };
  #};
  system.stateVersion = "25.05"; # Did you read the comment?
}
