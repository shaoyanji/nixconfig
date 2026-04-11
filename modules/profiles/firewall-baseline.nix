{
  lib,
  ...
}: {
  # Baseline host firewall posture:
  # - enabled by default
  # - only SSH is open globally
  # - host profiles can extend per-service/per-interface rules as needed
  networking.firewall = {
    enable = lib.mkDefault true;
    allowPing = lib.mkDefault false;
    allowedTCPPorts = lib.mkDefault [22];
  };
}
