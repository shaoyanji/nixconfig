{
  self,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    self.modules."profiles.base-desktop-environment"
    (import ../../modules/profiles/grub-boot.nix {
      inherit lib;
      device = "/dev/sda";
    })
  ];
  services.xserver.videoDrivers = ["amdgpu"];

  hardware.graphics.extraPackages = [
    pkgs.mesa.opencl
  ];
  system.stateVersion = "24.05";
  services.displayManager.sddm.enable = true;
  programs.dms-greeter.enable = false;
  ssh.ca.enableClient = false;
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
