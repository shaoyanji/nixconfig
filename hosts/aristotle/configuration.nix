{pkgs, ...}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/profiles/base-desktop-environment.nix
    ../../modules/profiles/laptop.nix
  ];

  boot.supportedFilesystems = ["nfs"];

  fileSystems."/Volumes/data" = {
    device = "192.168.3.25:/data";
    fsType = "nfs";
    options = ["nfsvers=4" "soft" "rw" "intr"];
  };

  networking.firewall.allowedTCPPorts = [2049];
  networking.hostName = "aristotle";
  system.stateVersion = "26.05";
}
