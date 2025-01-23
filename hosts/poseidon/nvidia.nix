{config, ...}: {
  imports = [
    ../common/nvidia.nix
  ];
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    prime = {
      nvidiaBusId = "PCI:1:0:0";
      amdgpuBusId = "PCI:5:0:0";
    };
  };
}
