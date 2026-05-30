{
  config,
  lib,
  ...
}: {
  # This host is an on-demand benchmark node, so keep baseline PM explicit.
  powerManagement.enable = true;

  services.xserver.enable = lib.mkDefault false;
  services.xserver.videoDrivers = ["nvidia"];

  nixpkgs.config = {
    nvidia.acceptLicense = true;
    cudaSupport = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = false;
  };

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;
    nvidiaSettings = false;
    modesetting.enable = true;
    # Keep the driver warm enough for repeatable CUDA startup without adding laptop/offload complexity.
    # Disabled due to nixpkgs bug with persistenced package
    nvidiaPersistenced = false;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
  };

  boot.kernelModules = [
    "nvidia"
    "nvidia_uvm"
  ];
}
