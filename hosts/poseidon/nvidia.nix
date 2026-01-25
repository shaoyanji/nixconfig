{
  config,
  lib,
  ...
}: {
  imports = [
    ../common/nvidia.nix
  ];
  services.xserver.videoDrivers = ["amdgpu" "nvidia"];
  hardware.nvidia = {
    open = lib.mkForce true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      nvidiaBusId = "PCI:1:0:0";
      amdgpuBusId = "PCI:5:0:0";
    };
  };
}
