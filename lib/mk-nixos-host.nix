# Thin wrapper around nixpkgs.lib.nixosSystem.
{
  nixpkgs,
  inputs,
  self,
  ...
}: {
  system,
  modules,
  # The inventory key. `networking.hostName` was declared in 20 host files and
  # every one of them repeated its own directory name, so the registry already
  # knew the answer. mkDefault (1000) is weaker than a plain definition, so a
  # host that genuinely needs a different hostname still wins without a conflict.
  hostName ? null,
  specialArgs ? {inherit inputs self;},
  ...
}:
nixpkgs.lib.nixosSystem {
  inherit system specialArgs;
  modules =
    nixpkgs.lib.optional (hostName != null) (
      {lib, ...}: {
        networking.hostName = lib.mkDefault hostName;
      }
    )
    ++ modules;
}
