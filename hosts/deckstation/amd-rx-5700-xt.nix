{
  ...}:
{
  services.xserver.videoDrivers = ["amdgpu"];

  # Minimal Mesa + amdgpu driver. enable32Bit is left to steamos.nix
  # (mkForce true). No rocm/OpenCL packages — this is a Steam / Sunshine
  # streaming host, not an AI workload target.
  hardware.graphics.enable = true;

  boot.kernelModules = ["amdgpu"];
}
