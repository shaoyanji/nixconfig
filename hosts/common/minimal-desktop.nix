{...}: {
  # Compatibility wrapper: canonical profile lives at modules/profiles/minimal-desktop.nix.
  imports = [
    ../../modules/profiles/minimal-desktop.nix
  ];
}
