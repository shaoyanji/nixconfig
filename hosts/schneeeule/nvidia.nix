{config, lib, pkgs, ...}:
{
  imports = [
      ../common/nvidia.nix
  ];
 
  services.xserver.videoDrivers = [ "intel" ];
  
  hardware.nvidia = {
    #     package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
     package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      nvidiaBusId = "PCI:9:0:0";
      intelBusId = "PCI:0:2:0";
    };
  };
 }
