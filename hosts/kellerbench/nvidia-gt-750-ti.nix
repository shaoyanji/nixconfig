{
  config,
  pkgs,
  ...
}: {
  # Freeze to 6.12 LTS kernel to avoid constant out-of-tree legacy_580 rebuilds
  # and upstream kernel API breakages on the Kepler dGPU.
  boot.kernelPackages = pkgs.linuxPackages_6_12;

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

  # The proprietary driver exposes no KMS node by default, so wlroots falls back
  # to its headless backend. Why: docs/gpu-kms.md.
  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "nvidia_drm.fbdev=1"
    # legacy_580 + gamescope quirk: the console framebuffer blanks after
    # ~10 s without mouse/input activity (screen goes dark until input).
    # consoleblank=0 disables the VT blank timer entirely; gamescope/Steam
    # handle their own display sleep via DPMS.
    "consoleblank=0"
  ];
}
