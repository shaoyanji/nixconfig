# AMD Radeon RX 5700 (Navi 10) GPU profile for eisen.
{pkgs, ...}: {
  services.xserver.videoDrivers = ["amdgpu"];

  hardware.graphics = {
    enable = true;
    # 32-bit GL is forced on by steamos.nix (mkForce true) for legacy
    # Steam games.  We leave it unset here so steamos wins.
    extraPackages = with pkgs; [
      mesa.opencl # OpenCL for compute-offload (darktable, etc.)
    ];
  };

  # VAAPI defaults to the radeonsi Gallium driver in mesa; no override
  # needed — auto-detection handles this correctly for AMD GPUs.

  boot.kernelModules = ["amdgpu"];
  boot.kernelParams = ["video=HDMI-A-1:1920x1080@60"];

  # ffmpeg-full with hardware codec support for media workflows.
  # mesa provides the VAAPI/VDPAU backends at runtime (no separate
  # driver packages needed for AMD — radeonsi ships inside mesa).
  environment.systemPackages = with pkgs; [
    ffmpeg-full
  ];
}
