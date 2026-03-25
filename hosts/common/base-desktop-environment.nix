{...}: {
  # Compatibility wrapper: canonical profile lives at modules/profiles/base-desktop-environment.nix.
  imports = [
    ../../modules/profiles/base-desktop-environment.nix
  ];
}
