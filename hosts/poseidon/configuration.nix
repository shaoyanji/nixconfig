{inputs, config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nvidia.nix
      #../common/steam.nix
      #      ../common/base-desktop-environment.nix
      ../common/minimal-desktop.nix
    ];
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_cachyos;
  boot = {
    #extraModulePackages = with config.boot.kernelPackages; [v4l2loopback.out];
    #kernelModules = [
    #  "v4l2loopback"
    #];
    #extraModprobeConfig = ''
    #  options v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
    #'';
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  networking.hostName = "poseidon"; # Define your hostname.
  #environment={
  #systemPackages = with pkgs; [
  #];
  #variables = {
  # };
  #};
  system.stateVersion = "25.05"; # Did you read the comment?
}
