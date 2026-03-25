{...}: {
  # Compatibility wrapper: canonical role lives at modules/roles/minimal.nix.
  imports = [
    ../roles/minimal.nix
  ];
}
