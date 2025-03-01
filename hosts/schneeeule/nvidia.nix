{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../common/nvidia.nix
  ];

  services.xserver.videoDrivers = ["intel"];
  nixpkgs.config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
    cudaSupport = true; # Enables CUDA support
  };
  nixpkgs.config.allowBroken = true;

  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
    #package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      nvidiaBusId = "PCI:9:0:0";
      intelBusId = "PCI:0:2:0";
    };
  };
}
