{ config
, lib
, ...
}: {
  # ares desktop case hosts a GTX 750 Ti (Kepler sm_30) dGPU on /dev/sda,
  # paired with an i5-6500 Skylake mainboard.  Mirrors
  # hosts/kellerbench/nvidia-gt-750-ti.nix verbatim: same
  # nvidiaPackages.legacy_580 driver, same nvidia_drm KMS
  # force-modprobe.  Pair with the cage kiosk compositor from steamos.nix
  # (greetd auto-logs devji into gamescope-session) that consumes
  # /dev/dri/card0 via seatd.
  #
  # Group wiring below is co-located with the GPU profile so devji
  # can open /dev/dri/renderD* (render), /dev/dri/card0 (video), and
  # /dev/input/event* (input) whoever imports this profile.  base-node
  # grants only networkmanager + wheel; without these extraGroups a
  # Wayland session for devji fails to acquire the DRM lease and the
  # user lands on a black screen.
  powerManagement.enable = true;

  services.xserver.videoDrivers = lib.mkForce [ "modesetting" "nvidia" ];

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
    prime = {
      nvidiaBusId = "PCI:1@0:0:0";
    };
  };

  boot.kernelModules = [
    "nvidia"
    "nvidia_uvm"
    "nvidia_modeset"
    "nvidia_drm"
  ];

  # Co-located group wiring (see top-of-file comment for rationale).
  # lib.mkAfter (priority ~10) appends to the extraGroups list set by
  # base-node.nix without overriding its wheel/networkmanager
  # ownership; mkAfter on a list attribute merges additively.
  users.users.devji.extraGroups = lib.mkAfter [ "video" "render" "input" ];

  # Force nvidia_drm KMS on so any wlroots-based compositor (Niri,
  # gamescope, cage, sway, etc.) can grab the DRM device via seatd.
  # Without modeset=1 the proprietary driver exposes no KMS node
  # (nvidia_drm modprobe defaults to modeset=0 / fbdev=0), so
  # /dev/dri/card0 either lacks KMS or seatd cannot enumerate the
  # seat as graphics-capable.  wlroots then selects the headless
  # backend as a safe-mode fallback (logs:
  # `wlserver [backend/headless/backend.c:67] Creating headless
  # backend`).  fbdev=1 also stabilises modesetting on legacy
  # Kepler (sm_30), where the proprietary driver prefers fbdev
  # for legacy framebuffer paths.
  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "nvidia_drm.fbdev=1"
  ];
}
