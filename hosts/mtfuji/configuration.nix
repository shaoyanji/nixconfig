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
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "mtfuji";

  system.stateVersion = "25.05";
}
