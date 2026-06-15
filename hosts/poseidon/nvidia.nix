{
  pkgs,
  config,
  lib,
  ...
}: {
  imports = [
    ../../modules/profiles/nvidia.nix
  ];
  services.xserver.videoDrivers = [
    "amdgpu"
    "nvidia"
  ];
  hardware.nvidia = {
    open = lib.mkForce true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    nvidiaPersistenced = lib.mkForce false;
    prime = {
      nvidiaBusId = "PCI:1:0:0";
      amdgpuBusId = "PCI:6:0:0";
    };
  };

  services.ollama = {
    # package = pkgs.ollama-cuda;
    loadModels = lib.mkForce [
      "lfm2.5:latest"
    ];
  };
  # boot.kernelParams = ["nvidia.NVreg_EnableGpuFirmware=0"];
}
