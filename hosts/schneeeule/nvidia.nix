{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/profiles/nvidia.nix
  ];

  # extraPackages = with pkgs; [nvidia-vaapi-driver];
  services.xserver.videoDrivers = ["intel"];
  nixpkgs.config = {
    nvidia.acceptLicense = true;
    cudaSupport = true;
  };

  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
  hardware.nvidia = {
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
    prime = {
      nvidiaBusId = "PCI:9:0:0";
      intelBusId = "PCI:0:2:0";
    };
  };
}
