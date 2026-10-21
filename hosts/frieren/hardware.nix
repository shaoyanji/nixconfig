# Hardware acceleration for i5-8250U (Kaby Lake R, Intel UHD Graphics 620).
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

  # --- Dell D6000 Universal Dock: desktop-only ---
  # Enabled by `specialisation.desktop`, so the headless boot carries neither
  # evdi nor the DisplayLink daemon.

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
