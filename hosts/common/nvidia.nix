{
  lib,
  pkgs,
  ...
}: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    #    extraPackages = with pkgs; [ nvidia-vaapi-driver ];
  };
  nixpkgs.config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
    cudaSupport = true; # Enables CUDA support
  };
  #nixpkgs.config.allowBroken = true;
  services.xserver.videoDrivers = ["nvidia"];
  #  boot.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" "i2c-nvidia_gpu" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    forceFullCompositionPipeline = true;
    prime = {
      offload.enable = true;
      sync.enable = false;
    };
  };
  specialisation = {
    gaming.configuration = {
      system.nixos.tags = ["gaming"];
      services.tailscale.enable = lib.mkForce false;
      networking.nameservers = lib.mkDefault []; 
      networking.search = lib.mkDefault [];
      hardware.nvidia = {
        #package = config.boot.kernelPackages.nvidiaPackages.stable;
        #package = config.boot.kernelPackages.nvidiaPackages.beta;
        prime = {
          offload.enable = lib.mkForce false;
          offload.enableOffloadCmd = lib.mkForce false;
          sync.enable = lib.mkForce true;
        };
      };
    };
  };
  # Nvidia Docker
  # virtualisation.docker.enableNvidia = true;
  # libnvidia-container does not support cgroups v2 (prior to 1.8.0)
  # https://github.com/NVIDIA/nvidia-docker/issues/1447

  # environment.systemPackages = with pkgs; [
  #    protonup
  #nvidia-docker
  #nvidia-container-toolkit
  #nvidia-modprobe
  #nvidia-settings
  #nvidia-smi
  #nvidia-xconfig
  #nvidia-cuda-toolkit
  #nvidia-cuda-dev
  #nvidia-cuda-doc
  #nvidia-cuda-samples
  #nvidia-opencl-icd
  #nvidia-opencl-dev
  #nvidia-opencl-doc
  #];
  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "/home/devji/.steam/root/compatibilitytools.d";
  };

  #  services.ollama = {
  #  enable = true;
  #  acceleration = "cuda";
  #};
}
