{
  config,
  lib,
  ...
}: {
  # This host is an on-demand benchmark node, so keep baseline PM explicit.
  powerManagement.enable = true;

  services.xserver.enable = lib.mkForce false;
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
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = false;
    nvidiaSettings = false;
    modesetting.enable = true;
    nvidiaPersistenced = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
  };

  boot.kernelModules = [
    "nvidia"
    "nvidia_uvm"
  ];
}
