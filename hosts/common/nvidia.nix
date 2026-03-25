{...}: {
  # Compatibility wrapper: canonical profile lives at modules/profiles/nvidia.nix.
  imports = [
    ../../modules/profiles/nvidia.nix
  ];
}
