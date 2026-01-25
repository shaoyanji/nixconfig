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
    package = "beta";
    prime = {
      nvidiaBusId = "PCI:1:0:0";
      amdgpuBusId = "PCI:5:0:0";
    };
  };
}
