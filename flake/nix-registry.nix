# The flake registry: `.#nixFiles` (every tracked `.nix`, by path) and
# `.#modules.<kind>` (the import closure of that kind's hosts, named for import).
# Why a closure: AGENTS.nix `dendritic-flake`; usage: AGENTS.md.
{
  lib,
  hostInventory,
  nixFilesCtl,
}: let
  inherit (nixFilesCtl) paths byPath relPath;
  importsOf = p: nixFilesCtl.importsOfPath p;

  # `lib.subtractLists seen xs` is `xs` minus `seen` (the library's first argument
  # is the list being removed); reversed, the walk re-adds files and never ends.
  reachable = start: let
    step = frontier: builtins.concatLists (map importsOf frontier);
    go = seen: frontier:
      if frontier == []
      then seen
      else let
        next = lib.unique (lib.subtractLists seen (step frontier));
      in
        go (seen ++ next) next;
  in
    go (lib.unique start) (lib.unique start);

  # Roots are the path entries in a host's module list; `inputs.x.nixosModules.*`,
  # inline lambdas and already-applied imports are not files this walk knows.
  rootsFor = kind:
    lib.concatMap
    (h: map relPath (builtins.filter builtins.isPath (h.modules or [])))
    (lib.attrValues (lib.filterAttrs (_: h: h.kind == kind) hostInventory));

  nameOf = p:
    lib.replaceStrings ["/"] ["."]
    (lib.removeSuffix ".nix" (lib.removePrefix "modules/" p));

  namespace = kind: let
    modulePaths =
      builtins.filter (p: lib.hasPrefix "modules/" p && builtins.elem p paths)
      (reachable (rootsFor kind));
    names = map nameOf modulePaths;
  in {
    files = builtins.listToAttrs (map (p: {
        name = nameOf p;
        value = byPath.${p};
      })
      modulePaths);
    # `listToAttrs` keeps the last of a collision silently; the check asserts
    # this is empty instead.
    duplicates = lib.subtractLists (lib.unique names) names;
    count = builtins.length modulePaths;
    inherit names;
  };

  nixos = namespace "nixos";
  homeManager = namespace "home";
  darwin = namespace "darwin";
in {
  nixFiles = nixFilesCtl.tree;

  modules = {
    nixos = nixos.files;
    homeManager = homeManager.files;
    darwin = darwin.files;
  };

  # Read by `checks.<system>.nix-registry`; `dangling` is prose as often as it is
  # a broken import, so it is reported, not gated.
  registry = {
    count = nixFilesCtl.count;
    namespaced = {
      nixos = nixos.count;
      homeManager = homeManager.count;
      darwin = darwin.count;
    };
    duplicates = nixos.duplicates ++ homeManager.duplicates ++ darwin.duplicates;
    dangling = lib.unique (
      builtins.filter (p: !(builtins.elem p paths)) (
        builtins.concatLists (map importsOf paths)
      )
    );
  };
}
