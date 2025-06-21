{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    #    ./configuration2.nix
    ./configuration.nix
  ];

  networking.hostName = "poseidon"; # Define your hostname.
  environment = {
    systemPackages = with pkgs; [
      inputs.quickshell.packages.${stdenv.hostPlatform.system}.default
    ];
    #variables = {
    # };
  };

  programs.qt.enable = true;
}
