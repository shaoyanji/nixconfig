{...}: {
  # Compatibility wrapper: canonical profile lives at modules/profiles/laptop.nix.
  imports = [
    ../../modules/profiles/laptop.nix
  ];
}
