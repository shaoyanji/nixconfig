{self, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
    self.modules."profiles.steam"
    self.modules."profiles.impermanence"
    self.modules."profiles.base-desktop-environment"
    self.modules."profiles.laptop"
  ];

  ssh.ca.enableClient = false;

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
