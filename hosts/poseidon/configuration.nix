{inputs, config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nvidia.nix
      ./steam.nix
      ../base-desktop-environment.nix
      ../minimal-desktop.nix
    ];
  networking.hostName = "poseidon"; # Define your hostname.
  environment.systemPackages = with pkgs; [
    inputs.zen-browser.packages.${pkgs.system}.specific
  ];
  system.stateVersion = "24.05"; # Did you read the comment?
}
