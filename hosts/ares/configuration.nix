{pkgs, ...}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/profiles/impermanence.nix
    ../../modules/profiles/base-desktop-environment.nix
    ../../modules/profiles/laptop.nix
  ];

  environment.systemPackages = with pkgs; [
    alacritty
  ];
  networking.hostName = "ares";
  system.stateVersion = "25.05";
}
