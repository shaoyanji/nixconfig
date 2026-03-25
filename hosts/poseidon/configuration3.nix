{...}: {
  # Compatibility wrapper: canonical host entrypoint lives at configuration.nix.
  imports = [
    ./configuration.nix
  ];
}
