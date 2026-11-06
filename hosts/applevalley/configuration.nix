{
  self,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    self.modules."profiles.desktop-client"
    self.modules."profiles.laptop"
  ];
  environment.systemPackages = with pkgs; [
    btrfs-progs
  ];

  system.stateVersion = "24.11";
}
