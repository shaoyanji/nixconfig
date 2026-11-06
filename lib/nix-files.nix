# Every tracked `.nix` file as data: a nested path tree and the import edges
# between files, walked once for `lib/knowledge-graph.nix` and
# `flake/nix-registry.nix`. Rationale: AGENTS.nix `dendritic-flake`.
{
  lib,
  root ? ../.,
}: let
  rootStr = toString root;
  rel = p: lib.removePrefix "${rootStr}/" (toString p);

  allFiles = lib.filesystem.listFilesRecursive root;
  files = builtins.filter (f: lib.hasSuffix ".nix" (toString f)) allFiles;
  paths = map rel files;

  # `modules/services/zettel-graph.nix` -> ["modules" "services" "zettel-graph.nix"].
  # Leaves keep `.nix`: a directory is never named so, so `flake.nix` and `flake/`
  # cannot collide (stripping it lost 17 files to one merged leaf).
  segments = p: lib.splitString "/" (rel p);

  # Path-valued leaves, so `.#nixFiles.modules.services.zettel-graph` is the
  # file itself and can be handed to `imports = [ ... ]` unchanged.
  tree =
    builtins.foldl' (acc: f: lib.recursiveUpdate acc (lib.setAttrByPath (segments f) f)) {}
    files;

  normalisePath = path: let
    segs = lib.splitString "/" path;
    step = acc: seg:
      if seg == "" || seg == "."
      then acc
      else if seg == ".."
      then
        (
          if acc == []
          then []
          else lib.init acc
        )
      else acc ++ [seg];
  in
    lib.concatStringsSep "/" (builtins.foldl' step [] segs);

  pathTokens = text:
    builtins.filter (
      t:
        builtins.isString t
        && (lib.hasPrefix "./" t || lib.hasPrefix "../" t)
        && lib.hasSuffix ".nix" t
    )
    (builtins.split "[^A-Za-z0-9_./-]+" text);

  importsOf = p: let
    dir = dirOf p;
    targets = map (t:
      normalisePath (
        if dir == "."
        then t
        else "${dir}/${t}"
      ))
    (pathTokens (builtins.readFile (root + "/${p}")));
  in
    lib.unique (builtins.filter (t: t != p) targets);

  edges = builtins.listToAttrs (map (p: {
      name = p;
      value = importsOf p;
    })
    paths);
  # A token only becomes an edge when it resolves to a file in `paths`; callers
  # filter, so a dangle is a missing edge rather than a phantom file.
  importsOfPath = p: edges.${p} or [];
in {
  inherit files paths tree edges importsOfPath;
  relPath = rel;
  byPath = builtins.listToAttrs (map (f: {
      name = rel f;
      value = f;
    })
    files);
  count = builtins.length files;
}
