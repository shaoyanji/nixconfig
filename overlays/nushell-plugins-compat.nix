final: prev: let
  inherit (final) nushell;
in {
  nushellPlugins = builtins.mapAttrs (
    name: plugin:
      if plugin ? override
      then plugin.override {inherit nushell;}
      else plugin
  ) prev.nushellPlugins;
}