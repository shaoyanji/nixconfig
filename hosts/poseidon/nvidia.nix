{config, lib, pkgs, ...}:
{
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ nvidia-vaapi-driver ];
  };

  nixpkgs.config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
    cudaSupport = true; # Enables CUDA support
  };

  services.xserver.videoDrivers = [ "nvidia"];
  boot.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
    "i2c-nvidia_gpu"
  ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    forceFullCompositionPipeline = true;
    prime = {
    offload.enable = true;
    sync.enable = false;
    nvidiaBusId = "PCI:1:0:0";
    amdgpuBusId = "PCI:5:0:0";
  };
};
  specialisation = {
    gaming.configuration = {
      system.nixos.tags = [ "gaming" ];
        hardware.nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.stable;
        prime.offload.enable = lib.mkForce false;
        prime.offload.enableOffloadCmd = lib.mkForce false;
        prime.sync.enable = lib.mkForce true;
      };
    # Nvidia Docker
    # virtualisation.docker.enableNvidia = true;
    # libnvidia-container does not support cgroups v2 (prior to 1.8.0)
    # https://github.com/NVIDIA/nvidia-docker/issues/1447
    };
  };
}
