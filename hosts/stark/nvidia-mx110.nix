# stark — NVIDIA GeForce MX110 (Maxwell GM108M, sm_50) Optimus dGPU.
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Freeze to 6.12 LTS kernel to avoid constant out-of-tree legacy_580 rebuilds
  # and upstream kernel API breakages on the Maxwell dGPU.
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  services.xserver.videoDrivers = lib.mkForce ["modesetting" "nvidia"];

  nixpkgs.config.nvidia.acceptLicense = true;

  hardware.graphics = {
    enable = true;
    # 32-bit GL: programs.steam (steam.nix) enables it by default —
    # leave unset so Steam owns that decision.
  };

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;
    nvidiaSettings = false;
    # Disabled due to nixpkgs bug with persistenced package (see ares).
    nvidiaPersistenced = false;
    modesetting.enable = true;
    powerManagement.enable = true;
    # RTD3 runtime PM (finegrained) is not supported on Maxwell GM108M
    # (introduced on Turing/Ampere, partial on Pascal) — kept off.
    powerManagement.finegrained = false;
    prime = {
      offload = {
        enable = true;
        # Provides the `nvidia-offload` wrapper for Steam launch options.
        enableOffloadCmd = true;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  boot.kernelModules = [
    "nvidia"
    "nvidia_uvm"
    "nvidia_modeset"
    "nvidia_drm"
  ];

  # Group wiring: render + input appended after base-node/desktop-client
  # (which already grants video + docker). gamescope/niri need
  # /dev/dri/renderD* (render) and /dev/input/event* (input) under the
  # DMS greeter session.
  users.users.devji.extraGroups = lib.mkAfter ["render" "input"];

  # nvidia_drm KMS on so Wayland compositors can lease the DRM device.
  # Same trio as ares/kellerbench (legacy_580 quirk): modeset=1 + fbdev=1
  # for stable legacy modesetting, consoleblank=0 because gamescope/Steam
  # handle their own DPMS (prevents the 10 s VT blank).
  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "nvidia_drm.fbdev=1"
    "consoleblank=0"
  ];
}
