{config, ...}: {
  imports = [
    ../common/nvidia.nix
  ];
  services.xserver.videoDrivers = ["amdgpu"];
  hardware.nvidia = {
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    prime = {
      nvidiaBusId = "PCI:1:0:0";
      amdgpuBusId = "PCI:5:0:0";
    };
  };
}
