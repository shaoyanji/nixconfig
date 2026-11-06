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

  # The one naming rule for the import namespace (`.#modules`), used in both
  # directions: a chain writes the name, the walk reads it back to an edge.
  # `modules/profiles/base-node.nix` -> `profiles.base-node`; a file named after
  # its directory does not repeat the word, and `default.nix` is the directory:
  # `modules/global/global.nix` -> `global`, `modules/net/dns/default.nix` -> `net.dns`.
  moduleFiles = builtins.filter (p: lib.hasPrefix "modules/" p) paths;
  nameOf = p: let
    parts = lib.splitString "/" (lib.removePrefix "modules/" (lib.removeSuffix ".nix" p));
    n = builtins.length parts;
    stem = builtins.elemAt parts (n - 1);
  in
    if n > 1 && (stem == "default" || stem == builtins.elemAt parts (n - 2))
    then lib.concatStringsSep "." (lib.init parts)
    else lib.concatStringsSep "." parts;
  # `listToAttrs` keeps the last of a collision silently; `checks.<system>.nix-registry`
  # counts names against files and fails instead.
  # A PATH, not the relative string: `self.modules."x"` is handed straight to
  # `imports = [ ... ]`, and a relative string fails there with "doesn't represent
  # an absolute path". The walk keeps both: `byName` for consumers, `nameOf` for
  # the edges below.
  byPath = builtins.listToAttrs (map (f: {
      name = rel f;
      value = f;
    })
    files);
  byName = builtins.listToAttrs (map (p: {
      name = nameOf p;
      value = byPath.${p};
    })
    moduleFiles);

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

  # `self.modules."roles.home"` (and the unquoted form). Quoted names are the
  # convention; both are read so an edge cannot disappear because of the syntax.
  # Split on the prefix and read the name off the chunk that follows: a regex
  # capture here would also hand back the dotted segments.
  nameRefs = text: let
    # Comments name things too, and a name in prose is not an edge. Dropping them
    # also keeps an example in a header from looking like a real import.
    code = lib.concatStringsSep "\n" (map (l: builtins.head (builtins.split "#" l)) (lib.splitString "\n" text));
    # Both vocabularies: a chain names a module as `moduleFiles."x"` before any
    # `self` exists, a module as `self.modules."x"`.
    chunks = builtins.filter builtins.isString (builtins.split ''self\.modules\.|moduleFiles\.'' code);
    # The chunk runs to the end of the file; match against its first line only.
    # A whole-file `.*` pattern is a regex over tens of kilobytes and nix dumps
    # core on it (measured on the larger module files).
    refIn = chunk: let
      line = builtins.head (builtins.split "\n" chunk);
      quoted = builtins.match "\"([A-Za-z0-9_.-]+)\".*" line;
      bare = builtins.match "([A-Za-z0-9_.-]+).*" line;
    in
      if quoted != null
      then builtins.head quoted
      else if bare != null
      then builtins.head bare
      else null;
  in
    if chunks == []
    then []
    else builtins.filter (n: n != null) (map refIn (builtins.tail chunks));

  # `AGENTS.nix` is the note store: prose in a Nix string, not a config. A
  # module named there is being discussed, not imported, and counting it made
  # `ops:kg:module` report the note as an importer — and made a placeholder in a
  # design note read as a dangling name. One rule, used by the edges and by the
  # registry's dangling-name scan, so the two cannot disagree.
  nameRefsOf = p:
    if p == "AGENTS.nix"
    then []
    else nameRefs (builtins.readFile (root + "/${p}"));

  importsOf = p: let
    dir = dirOf p;
    text = builtins.readFile (root + "/${p}");
    targets =
      map (
        t:
          normalisePath (
            if dir == "."
            then t
            else "${dir}/${t}"
          )
      )
      (pathTokens text)
      ++ map (n: rel byName.${n}) (builtins.filter (n: builtins.hasAttr n byName) (nameRefsOf p));
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
  inherit moduleFiles nameOf byPath byName nameRefs nameRefsOf;
  relPath = rel;
  count = builtins.length files;
}
