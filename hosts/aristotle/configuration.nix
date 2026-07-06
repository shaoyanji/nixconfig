{
  config,
  pkgs,
  lib,
  ...
}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/profiles/base-desktop-environment.nix
    ../../modules/profiles/laptop.nix
  ];

  boot.supportedFilesystems = ["nfs"];
  ssh.ca.enableClient = true;

  fileSystems."/Volumes/data" = {
    device = "192.168.3.25:/data";
    fsType = "nfs";
    options = ["nfsvers=4" "soft" "rw" "intr"];
  };

  networking.firewall.allowedTCPPorts = [2049];
  networking.hostName = "aristotle";

  services.displayManager.sddm = {
    enable = false;
    wayland.enable = true;
  };

  programs.dank-material-shell.greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home;
  };

  system.stateVersion = "26.05";
}
