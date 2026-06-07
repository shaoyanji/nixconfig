{
  pkgs,
  ...
}: {
  # --- Hardware acceleration ---
  nixpkgs.config.packageOverrides = pkgs: {
    intel-vaapi-driver = pkgs.intel-vaapi-driver.override {enableHybridCodec = true;};
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      libva-vdpau-driver
      intel-compute-runtime-legacy1
      vpl-gpu-rt
      intel-ocl
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  # --- Power management ---
  powerManagement.powertop.enable = true;

  # --- Ollama ---
  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    openFirewall = true;
  };
}
