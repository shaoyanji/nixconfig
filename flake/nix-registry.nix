# The flake registry: `.#nixFiles` (every tracked `.nix`, by path) and
# `.#modules` (every file under `modules/`, named). Pure: the walk only, so a
# chain can use these names without depending on the flake outputs.
{
  lib,
  nixFilesCtl,
}: let
  inherit (nixFilesCtl) paths byPath;
  moduleFiles = builtins.filter (p: lib.hasPrefix "modules/" p) paths;

  # `modules/profiles/base-node.nix` -> `profiles.base-node`;
  # `modules/global/global.nix` -> `global` (a file named after its directory
  # does not repeat the word) and `modules/net/dns/default.nix` -> `net.dns`.
  nameOf = p: let
    parts = lib.splitString "/" (lib.removePrefix "modules/" (lib.removeSuffix ".nix" p));
    n = builtins.length parts;
    stem = builtins.elemAt parts (n - 1);
  in
    if n > 1 && (stem == "default" || stem == builtins.elemAt parts (n - 2))
    then lib.concatStringsSep "." (lib.init parts)
    else lib.concatStringsSep "." parts;

  names = map nameOf moduleFiles;
in {
  nixFiles = nixFilesCtl.tree;

  modules = builtins.listToAttrs (map (p: {
      name = nameOf p;
      value = byPath.${p};
    })
    moduleFiles);

  # Read by `checks.<system>.nix-registry`; `dangling` is prose as often as it is
  # a broken import, so it is reported, not gated.
  registry = {
    count = nixFilesCtl.count;
    modules = builtins.length moduleFiles;
    # `listToAttrs` keeps the last of a collision silently; the check asserts
    # this is empty instead.
    duplicates = lib.subtractLists (lib.unique names) names;
    dangling = lib.unique (
      builtins.filter (p: !(builtins.elem p paths)) (
        builtins.concatLists (map nixFilesCtl.importsOfPath paths)
      )
    );
  };
}
