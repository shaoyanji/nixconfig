{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/profiles/base-desktop-environment.nix
    (import ../../modules/profiles/grub-boot.nix {inherit lib; device = "/dev/sda";})
  ];
  networking.hostName = "aceofspades";
  services.xserver.videoDrivers = ["amdgpu"];

  hardware.graphics.extraPackages = [
    pkgs.mesa.opencl
  ];
  system.stateVersion = "24.05";
  services = {
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };
    };
  };
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
