# Hardware acceleration for i5-8250U (Kaby Lake R, Intel UHD Graphics 620).
# QuickSync supports H.264 + HEVC/H.265 encode + decode — excellent for
# 4K Jellyfin/Plex transcoding.
{ pkgs, ... }: {
  # --- Intel QuickSync VA-API ---
  nixpkgs.config.packageOverrides = pkgs: {
    intel-vaapi-driver = pkgs.intel-vaapi-driver.override { enableHybridCodec = true; };
  };

  hardware.graphics = {
    enable = true;
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

  # --- Power management (laptop-as-server, battery = built-in UPS) ---
  # powertop is intentionally NOT enabled: its `--auto-tune` boot service
  # enables USB autosuspend, which kills the Intel combo Bluetooth adapter
  # (the classic powertop BT-killer) — frieren needs reliable BT input for
  # the TV keyboard/mouse. `powerManagement.enable = true` (configuration.nix)
  # already handles CPU frequency scaling. Re-add powertop only if you also
  # add a udev rule exempting the BT USB device from autosuspend.
}
