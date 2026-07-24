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
      intel-compute-runtime # OpenCL (Gen9.5 compatible, NOT legacy1)
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  # --- Power management (laptop-as-server, battery = built-in UPS) ---
  powerManagement.powertop.enable = true;
}
