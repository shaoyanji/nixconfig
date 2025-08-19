{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./configuration.nix
  ];
  environment = {
    systemPackages = with pkgs; [
      # inputs.quickshell.packages.${stdenv.hostPlatform.system}.default
      inputs.caelestia.packages.${stdenv.hostPlatform.system}.default
      uwsm
    ];
  };

  qt.enable = true;

  services = {
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };
    };
  };
  system.stateVersion = "25.11"; # Did you read the comment?
}
