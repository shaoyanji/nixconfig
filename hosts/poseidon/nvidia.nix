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
    open = lib.mkForce true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    nvidiaPersistenced = lib.mkForce false;
    prime = {
      nvidiaBusId = "PCI:1:0:0";
      amdgpuBusId = "PCI:5:0:0";
    };
  };

  # Disable NVIDIA GSP firmware via kernel parameter to fix boot failure
  # The kernel_gsp.c assertion failure is caused by GSP firmware issues
  boot.kernelParams = ["nvidia.NVreg_EnableGpuFirmware=0"];
}
