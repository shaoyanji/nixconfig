{
  config,
  lib,
  ...
}: {
  # This host is an on-demand benchmark node, so keep baseline PM explicit.
  powerManagement.enable = true;

  # services.xserver.enable = lib.mkDefault true;
  services.xserver.videoDrivers = ["nvidia"];

  nixpkgs.config = {
    nvidia.acceptLicense = true;
    cudaSupport = true;
  };

  hardware.graphics = {
    enable = true;
    # enable32Bit = false;
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
    "nvidia_modeset"
    "nvidia_drm"
  ];

  # Force nvidia_drm KMS on so gamescope/wlroots can grab the DRM device
  # via seatd. Without modeset=1 the proprietary driver exposes no KMS
  # node (nvidia_drm modprobe defaults to modeset=0 / fbdev=0), so
  # /dev/dri/card0 either lacks KMS or seatd cannot enumerate the seat
  # as graphics-capable. wlroots then selects the headless backend as a
  # safe-mode fallback (logs: wlserver [backend/headless/backend.c:67]
  # Creating headless backend). fbdev=1 also stabilises gamescope on
  # legacy Kepler (sm_30) under modesetting.
  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "nvidia_drm.fbdev=1"
  ];
}
