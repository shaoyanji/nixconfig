# Standalone-HM user imports as inventory data — the same per-host split
# `fleet.hmUserFeatures` gives the embedded chain. The role/module list a
# standalone host builds lives next to its `features` in
# flake/host-inventory.nix (`hmModules`), so an edit lands on one host's
# file — `hosts/<name>.nix` — plus one inventory line, never on the chain.
# `hostInventory` and `fleetHost` arrive as extraSpecialArgs from the home
# assembler in flake/outputs.nix — both must be externally provided: an arg
# resolved through `_module.args` cannot drive `imports` (it forces `config`,
# which is the imports-position recursion trap).
{
  self,
  hostInventory,
  fleetHost ? "",
  ...
}: {
  imports = let
    entry =
      if builtins.isString fleetHost && builtins.hasAttr fleetHost hostInventory
      then hostInventory.${fleetHost} or {}
      else {};
  in
    map (m: self.modules.${m}) (entry.hmModules or []);
}
