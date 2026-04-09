{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia.nix
    ../../modules/profiles/steam.nix
    ../../modules/profiles/impermanence.nix
    ../../modules/profiles/base-desktop-environment.nix
    ../../modules/profiles/laptop.nix
  ];
  networking.hostName = "schneeeule";
  environment.systemPackages = with pkgs; [];

  fileSystems."/persist/data" = {
    device = "/dev/disk/by-uuid/ae50ae59-36e2-4e9a-88d0-04951f6a51fc";
    fsType = "ext4";
  };

  i18n.extraLocaleSettings = {
    LC_NUMERIC = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };
  services.thermald.enable = true;
  system.stateVersion = "25.05";
}
