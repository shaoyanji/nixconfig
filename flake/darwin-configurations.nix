{
  inputs,
  moduleSets,
}: let
  inherit (moduleSets) globalModulesMacos;
in {
  cassini = inputs.nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    specialArgs = {inherit inputs;};
    modules = globalModulesMacos ++ [../hosts/cassini/configuration.nix];
  };
}
