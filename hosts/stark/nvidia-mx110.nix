# stark — NVIDIA GeForce MX110 (Maxwell GM108M, sm_50) Optimus dGPU.
#
# The Inspiron 24 3477 AIO is a muxless Optimus box: the 23.8" panel is
# wired to the Intel HD 620 iGPU; the MX110 is a render-only device.
# Therefore:
#   - PRIME render OFFLOAD (not sync mode): the iGPU drives the desktop
#     and the Steam/gamescope session; games opt into the dGPU with
#     `nvidia-offload %command%` (Steam launch options) or prime-run.
#   - MX110 is Maxwell GM108M (sm_50, rebadged GeForce 920MX): the 580 branch
#     is the last driver series for Maxwell/Pascal →
#     config.boot.kernelPackages.nvidiaPackages.legacy_580, same driver
#     series as ares/kellerbench (GTX 750 Ti, sm_50/sm_30). The open kernel
#     module does NOT support Maxwell → open = false.
#   - cudaSupport stays OFF (unlike ares): nothing on this box needs
#     CUDA and forcing it rebuilds large dependency trees (AGENTS.md
#     build-avoidance traps) for no benefit.
#
# Bus IDs (verified with `lspci -nn | grep -Ei 'vga|3d'`):
#   Intel HD 620 → 00:02.0 → PCI:0:2:0
#   MX110        → 01:00.0 → PCI:1:0:0
#
# Primary renderer note: the iGPU enumerates first (00:02.0 < 01:00.0),
# so wlroots/smithay compositors (gamescope, niri/DMS) pick it as the
# primary DRM device without pinning. If the panel ever stays dark,
# pin WLR_DRM_DEVICES/AQ_DRM_DEVICES to
# /dev/dri/by-path/pci-0000:00:02.0-card.
{ config
, lib
, ...
}: {
  services.xserver.videoDrivers = lib.mkForce [ "modesetting" "nvidia" ];

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
  users.users.devji.extraGroups = lib.mkAfter [ "render" "input" ];

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
