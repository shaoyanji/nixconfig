{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/nas-client.nix
    inputs.sops-nix.nixosModules.sops
    ./ai.nix
  ];

  # Tailscale for mesh networking
  services = {
    tailscale = {
      enable = true;
      useRoutingFeatures = "both";
    };
    resolved.enable = true;
    resolved.settings.Resolve.Domains = ["~.cloudforest-kardashev.ts.net" "~.fritz.box" "~."];
  };

  networking.hostName = "mtfuji";

  system.stateVersion = "25.05";
}
