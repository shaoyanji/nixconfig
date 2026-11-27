# Intel Haswell (Gen 7.5) VAAPI facts shared by the i965 desktops.
{pkgs, ...}: {
  hardware.graphics.extraPackages = with pkgs; [
    intel-vaapi-driver
    libvdpau-va-gl
  ];

  environment.sessionVariables.LIBVA_DRIVER_NAME = "i965";
  environment.systemPackages = [pkgs.libva-utils];
}
