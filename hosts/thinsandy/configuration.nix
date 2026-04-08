{
  config,
  lib,
  pkgs,
  inputs,
  self,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/profiles/base-node.nix
    inputs.sops-nix.nixosModules.sops
    ./hardware.nix
    ./media-stack.nix
    ./dns.nix
    ./tools.nix
    ./networking.nix
    ./ai.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "thinsandy";

  system.stateVersion = "25.05";
}
