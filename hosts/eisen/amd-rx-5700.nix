# AMD Radeon RX 5700 (Navi 10) GPU profile for eisen.
#
# This host is both a 4K gaming rig (Steam + Sunshine GameStream) and a
# media transcoding target.  The RX 5700's VCN 2.0 block supports:
#   - H.264 / H.265 (HEVC) encode + decode
#   - VP9 decode (8K)
# via VAAPI (radeonsi Gallium driver in mesa) and VDPAU.
#
# - amdgpu kernel module drives the card.
# - mesa provides VAAPI + VDPAU backends for ffmpeg/Jellyfin/Plex.
# - libva-utils ships vainfo for debugging the encode/decode surface list.
# - No ROCm — Navi 10 has no CDNA compute silicon and ROCm support is
#   experimental at best; this host targets gaming + media, not AI.
{ pkgs, ... }:
{
  services.xserver.videoDrivers = [ "amdgpu" ];

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

  boot.kernelModules = [ "amdgpu" ];

  # ffmpeg-full with hardware codec support for media workflows.
  # mesa provides the VAAPI/VDPAU backends at runtime (no separate
  # driver packages needed for AMD — radeonsi ships inside mesa).
  environment.systemPackages = with pkgs; [
    ffmpeg-full
  ];
}
