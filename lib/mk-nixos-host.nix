{nixpkgs}: {
  system,
  modules,
  specialArgs ? {},
  ...
}:
  nixpkgs.lib.nixosSystem {
    inherit system modules specialArgs;
  }
