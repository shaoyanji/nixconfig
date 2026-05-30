{
  config,
  lib,
  ...
}: {
  imports = [
    ../../modules/profiles/nvidia.nix
  ];
  services.xserver.videoDrivers = ["amdgpu" "nvidia"];
  hardware.nvidia = {
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = lib.mkForce true;
    prime = {
      nvidiaBusId = "PCI:1:0:0";
      amdgpuBusId = "PCI:5:0:0";
    };
  };

}
