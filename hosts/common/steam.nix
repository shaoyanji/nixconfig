{...}: {
  # Compatibility wrapper: canonical profile lives at modules/profiles/steam.nix.
  imports = [
    ../../modules/profiles/steam.nix
  ];
}
