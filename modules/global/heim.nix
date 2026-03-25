{...}: {
  # Compatibility wrapper: canonical role lives at modules/roles/heim.nix.
  imports = [
    ../roles/heim.nix
  ];
}
