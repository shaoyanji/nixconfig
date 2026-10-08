# stark — Dell Inspiron 24 3477 All-in-One Steam desktop.
#
# Hardware:
#   CPU:  Intel Core i5-7200U (Kaby Lake-U, 2c/4t, 15 W)
#   GPU:  Intel HD 620 iGPU (drives the 23.8" 1080p panel) +
#         NVIDIA GeForce MX110 (Maxwell GM108M, sm_50) via PRIME render
#         offload → legacy_580 driver (./nvidia-mx110.nix)
#   RAM:  16 GB DDR4
#   Disk: SK hynix SC311 SATA SSD (system, disko main) +
#         1 TB HDD (Steam library, btrfs → /mnt/steam, disko hdd)
#   Boot: UEFI (systemd-boot)
#
# Role:  Steam Big Picture on a full desktop chain (eisen-style):
#        globalModulesNixos → niri + DankMaterialShell greeter +
#        role:heim userland. autoLogin drops devji straight into the
#        upstream gamescope-session (steam -gamepadui); if it exits,
#        the DMS greeter is the fallback (niri session selectable).
#        NOT the noDE steamos.nix kiosk path (ares) — the desktop
#        chain is wanted here.
#
# Storage: /mnt/steam = 1 TB HDD (btrfs+zstd, labeled `steam`). After
#          first boot own it once:
#            sudo chown devji:users /mnt/steam
#          Then add it in Steam: Settings → Storage → Add Drive →
#          /mnt/steam. Games that benefit from the dGPU: right-click →
#          Properties → Launch Options → `nvidia-offload %command%`.
{pkgs, ...}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia-mx110.nix
    ../../modules/profiles/steam.nix
    ../../modules/profiles/base-desktop-environment.nix
    ../../modules/profiles/base-node.nix
  ];

  networking.hostName = "stark";

  # --- Desktop (eisen-style): niri compositor + DankMaterialShell greeter ---
  services.displayManager.sddm = {
    enable = false;
    wayland.enable = true;
  };

  # Autologin: boot straight into Steam Big Picture under
  # gamescope-session so the AIO behaves like a console with zero
  # interaction after power-on. The DMS greeter module runs the
  # resolved session via initial_session; if it exits, greetd falls
  # back to the DMS greeter login screen (niri session selectable).
  services.displayManager.autoLogin = {
    enable = true;
    user = user.name;
  };
  services.displayManager.defaultSession = "steam";

  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home; # Sync themes with user's DankMaterialShell config
  };

  # --- Steam under gamescope ---
  # steam.nix enables programs.steam.gamescopeSession, so greetd/DMS can
  # launch the upstream gamescope-session script directly. The session
  # renders on the HD 620 iGPU (primary DRM device); individual games
  # opt into the MX110 via nvidia-offload/prime-run (see header).
  programs.gamescope.enable = true;

  # Thermald — 15 W Kaby Lake-U in a sealed AIO chassis.
  services.thermald.enable = true;

  # --- Hardware Video Acceleration (Intel HD 620 QuickSync) ---
  # Enables VAAPI hardware decode/encode for H.264, HEVC 8/10-bit, and VP9.
  # Keeps video decode overhead off the 15 W dual-core CPU in Steam CEF and browsers.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # iHD driver for Kaby Lake Gen9 QuickSync
      intel-vaapi-driver # i965 fallback
      libva-vdpau-driver
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  # --- Shader Cache on SSD ---
  # With 16 GB RAM, stark avoids eisen's 16 GB tmpfs RAM disk. However,
  # keeping shader caches on the 5400 RPM HDD (/mnt/steam) introduces
  # severe random-read latency during game launches and level loads.
  # Instead, shaders live on the SK hynix SATA SSD root filesystem.
  systemd.tmpfiles.rules = [
    "d ${user.home}/.local/share/Steam/steamapps/shadercache 0755 devji users - -"
  ];

  # --- Btrfs auto-scrub (monthly) ---
  # The SSD root and the 1 TB Steam library are both btrfs. Monthly
  # scrub detects and repairs bit rot using checksums.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [
      "/"
      "/mnt/steam"
    ];
  };

  environment.systemPackages = with pkgs; [
    btop # system monitor
    libva-utils # vainfo — check HD 620 VAAPI decode surfaces
  ];

  system.stateVersion = "26.05";
}
