# Hardware acceleration for i5-8250U (Kaby Lake R, Intel UHD Graphics 620).
# QuickSync supports H.264 + HEVC/H.265 encode + decode — excellent for
# 4K Jellyfin/Plex transcoding.
{pkgs, ...}: {
  # --- Intel QuickSync VA-API ---
  nixpkgs.config.packageOverrides = pkgs: {
    intel-vaapi-driver = pkgs.intel-vaapi-driver.override {enableHybridCodec = true;};
  };

  hardware.graphics = {
    enable = true;
    # This box is a NAS/media server with an Intel iGPU — no Steam, no Wine,
    # no 32-bit games. Leaving the base-desktop default (true on x86_64) pulls
    # a second mesa AND a second llvm-21.1.8-lib for graphics-drivers-32bit:
    # measured 2026-10-17 at ~812 MiB of the frieren closure. A plain value
    # beats the profile's `lib.mkDefault`.
    enable32Bit = false;
    extraPackages = with pkgs; [
      intel-media-driver # iHD — modern QuickSync driver
      intel-vaapi-driver # i965 — legacy VA-API backend (hybrid codecs)
      libva-vdpau-driver # VDPAU → VA-API bridge
      vpl-gpu-rt # oneVPL runtime (Gen9+, H.264/HEVC/H.265)
      intel-compute-runtime-legacy1 # OpenCL legacy (correct for Gen8-Gen11 i.e. KBL)
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  # --- Dell D6000 Universal Dock (DisplayLink / EVDI) ---
  # Dell D6000 drives external displays over USB 3.0 / USB-C via DisplayLink (DL-6950).
  # Synaptics upstream zip is fetched via fetchurl so hydra/nixbuild can build it without requireFile prompts.
  nixpkgs.overlays = [
    (final: prev: {
      displaylink = prev.displaylink.overrideAttrs (_old: {
        src = final.fetchurl {
          url = "https://www.synaptics.com/sites/default/files/exe_files/2026-06/DisplayLink%20USB%20Graphics%20Software%20for%20Ubuntu6.3-EXE.zip";
          hash = "sha256-cmmFbHUnBgxRMhXOG1o2/vB02Oicq4m8qxPfNCrM4Jg=";
          name = "displaylink-630.zip";
        };
      });
    })
  ];

  services.xserver.videoDrivers = ["displaylink" "modesetting"];

  # EVDI kernel module requires drm_ttm_helper for GEM buffer mapping symbols (drm_gem_ttm_vmap)
  boot.kernelModules = ["drm_ttm_helper" "evdi"];

  systemd.services.dlm = {
    wantedBy = ["multi-user.target"];
  };

  # Disable USB autosuspend: kernel 6.12 defaults enable_autosuspend=Y (and usbcore.autosuspend=2),
  # which aggressively powers down BT adapters after 2s and drops DisplayLink DL-6950 ASIC / USB 3.0 hubs.
  boot.kernelParams = ["usbcore.autosuspend=-1"];

  services.udev.extraRules = ''
    # Prevent autosuspend on DisplayLink docks and external USB hubs
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="17e9", ATTR{power/control}="on"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="05e3", ATTR{power/control}="on"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="06c4", ATTR{power/control}="on"
  '';

  # Disable USB autosuspend for btusb: kernel 6.12 defaults enable_autosuspend=Y,
  # which aggressively powers down BT adapters after 2s and drops connection to MX Keys/Master.
  boot.extraModprobeConfig = ''
    options btusb enable_autosuspend=n
  '';

  # --- Power management (laptop-as-server, battery = built-in UPS) ---
  # powertop is intentionally NOT enabled: its `--auto-tune` boot service
  # enables USB autosuspend, which kills the Intel combo Bluetooth adapter
  # (the classic powertop BT-killer) — frieren needs reliable BT input for
  # the TV keyboard/mouse. `powerManagement.enable = true` (configuration.nix)
  # already handles CPU frequency scaling. Re-add powertop only if you also
  # add a udev rule exempting the BT USB device from autosuspend.

  # D.4.0: Graceful shutdown on low battery (~5%).
  # frieren is a laptop-as-server; its battery acts as a built-in UPS.
  # When mains power is lost and the battery drops to 5%, UPower triggers
  # a clean poweroff (systemctl poweroff), gracefully unmounting Btrfs
  # and stopping services before power is completely lost.
  services.upower = {
    enable = true;
    usePercentageForPolicy = true;
    percentageLow = 15;
    percentageCritical = 8;
    percentageAction = 5;
    criticalPowerAction = "PowerOff";
  };

  # --- TPM 2.0 (Intel PTT hardware cryptoprocessor) ---
  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };

  # Allow devji direct access to the TPM resource manager (/dev/tpmrm0)
  users.users.devji.extraGroups = ["tss"];

  environment.systemPackages = with pkgs; [
    age-plugin-tpm
    tpm2-tools
  ];
}
