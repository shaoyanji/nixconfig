{inputs, config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../base-desktop-environment.nix
    ];
  boot.loader = {
    grub = {
      device = "/dev/sda";
      enableCryptodisk = true;
      useOSProber = true;
      enable = true;
    };
  };
  networking.hostName = "aceofspades"; # Define your hostname.
  services.xserver.videoDrivers = [ "amdgpu" ];

  environment.systemPackages = with pkgs; [
  ];

  hardware.graphics.extraPackages = [
    pkgs.mesa.opencl
  ];
  system.stateVersion = "24.05"; # Did you read the comment?

}
