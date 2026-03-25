{...}: {
  # Compatibility wrapper: canonical profile lives at modules/profiles/impermanence.nix.
  imports = [
    ../../modules/profiles/impermanence.nix
  ];
}
