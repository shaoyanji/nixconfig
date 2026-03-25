{...}: {
  # Compatibility wrapper: canonical role lives at modules/roles/home.nix.
  imports = [
    ../roles/home.nix
  ];
}
