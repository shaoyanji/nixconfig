{inputs, config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../impermanence.nix
      ../base-desktop-environment.nix
      ../minimal-desktop.nix
    ];
  networking.hostName = "ares"; # Define your hostname.
  environment.systemPackages = with pkgs; [
    firefox
    inputs.zen-browser.packages.${pkgs.system}.twilight
    qutebrowser
  ];
  system.stateVersion = "24.11"; # Did you read the comment?

}
