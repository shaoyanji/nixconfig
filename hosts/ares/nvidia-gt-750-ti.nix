{
  config,
  lib,
  ...}: {
  # ares is a Steam-kiosk desktop — see hosts/ares/configuration.nix for
  # the desktop case migration note.  This file is a 1:1 copy of
  # hosts/kellerbench/nvidia-gt-750-ti.nix: same Kepler sm_30 GPU
  # (GTX 750 Ti), same nvidiaPackages.legacy_580 driver, same
  # nvidia_drm KMS force-modprobe.
  powerManagement.enable = true;

  services.xserver.videoDrivers = ["nvidia"];

  nixpkgs.config = {
    nvidia.acceptLicense = true;
    cudaSupport = true;
  };

  hardware.graphics = {
    enable = true;
  };

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;
    nvidiaSettings = false;
    modesetting.enable = true;
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

  # Force nvidia_drm KMS on so gamescope/cage/wlroots can grab the
  # DRM device via seatd. Without modeset=1 the proprietary driver
  # exposes no KMS node (nvidia_drm modprobe defaults to modeset=0 /
  # fbdev=0), so /dev/dri/card0 either lacks KMS or seatd cannot
  # enumerate the seat as graphics-capable. wlroots then selects the
  # headless backend as a safe-mode fallback (logs:
  # `wlserver [backend/headless/backend.c:67] Creating headless
  # backend`). fbdev=1 also stabilises gamescope on legacy Kepler
  # (sm_30) under modesetting.
  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "nvidia_drm.fbdev=1"
  ];
}
