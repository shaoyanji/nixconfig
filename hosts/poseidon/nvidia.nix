{
  config,
  lib,
  ...
}: {
  imports = [
    ../../modules/profiles/nvidia.nix
  ];
  services.xserver.videoDrivers = [
    "nvidia"
    "amdgpu"
  ];
  hardware.nvidia = {
    open = lib.mkForce true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    nvidiaPersistenced = lib.mkForce false;
    prime = {
      nvidiaBusId = "PCI:1:0:0";
      amdgpuBusId = "PCI:5:0:0";
    };
  };

  boot.kernelParams = ["nvidia.NVreg_EnableGpuFirmware=0"];
}
