{
  config,
  lib,
  pkgs,
  ...
}: {
  services.xserver.videoDrivers = ["amdgpu"];

  hardware.graphics = {
    enable = true;
    enable32Bit = false;
  };

  hardware.graphics.extraPackages = with pkgs; [
    mesa.opencl
    rocmPackages.clr
    rocmPackages.rocminfo
  ];

  boot.kernelModules = ["amdgpu"];

  environment.systemPackages = with pkgs; [
    rocmPackages.rocminfo
    rocmPackages.rocm-runtime
  ];
}
