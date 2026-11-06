# The flake registry: `.#nixFiles` (every tracked `.nix`, by path) and
# `.#modules` (every file under `modules/`, named for import). Pure: the walk
# only, so a chain can use these names without depending on the flake outputs.
{
  lib,
  nixFilesCtl,
}: let
  inherit (nixFilesCtl) paths byPath nameOf byName nameRefs moduleFiles;
  names = map nameOf moduleFiles;
in {
  nixFiles = nixFilesCtl.tree;

  modules = byName;

  # Read by `checks.<system>.nix-registry`; `dangling` is prose as often as it is
  # a broken import, so it is reported, not gated. A `self.modules."x"` that names
  # nothing is a different failure — it breaks the import, not the walk — and is.
  registry = {
    count = nixFilesCtl.count;
    modules = builtins.length moduleFiles;
    # `listToAttrs` keeps the last of a collision silently; the check asserts
    # this is empty instead.
    duplicates = lib.subtractLists (lib.unique names) names;
    unknownNames = lib.unique (
      builtins.concatMap (p: builtins.filter (n: !(builtins.hasAttr n byName)) (nameRefs (builtins.readFile (byPath.${p})))) paths
    );
    dangling = lib.unique (
      builtins.filter (p: !(builtins.elem p paths)) (
        builtins.concatLists (map nixFilesCtl.importsOfPath paths)
      )
    );
  };
}
