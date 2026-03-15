{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../common/minimal-desktop.nix
    inputs.nix-openclaw.nixosModules.openclaw-gateway
    inputs.sops-nix.nixosModules.sops
    ./hardware.nix
    ./media-stack.nix
    ./openclaw.nix
    ./tools.nix
    ./networking.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "thinsandy";

  nixpkgs.overlays = [
    inputs.nix-openclaw.overlays.default
  ];

  # Shared hard drive bind mount
  fileSystems."/var/lib/openclaw/.openclaw/workspace/share" = {
    device = "/srv/data/openclaw";
    options = ["bind"];
  };

  system.stateVersion = "25.05";
}
