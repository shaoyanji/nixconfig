# Every tracked `.nix` file as data: a nested path tree and the import edges
# between files, walked once for `lib/knowledge-graph.nix` and
# `flake/nix-registry.nix`. Rationale: AGENTS.nix `dendritic-flake`.
{
  lib,
  root ? ../.,
}: let
  rootStr = toString root;
  rel = p: p |> toString |> lib.removePrefix "${rootStr}/";

  allFiles = lib.filesystem.listFilesRecursive root;
  files = allFiles |> builtins.filter (f: f |> toString |> lib.hasSuffix ".nix");
  paths = map rel files;

  # `modules/services/zettel-graph.nix` -> ["modules" "services" "zettel-graph.nix"].
  # Leaves keep `.nix`: a directory is never named so, so `flake.nix` and `flake/`
  # cannot collide (stripping it lost 17 files to one merged leaf).
  segments = p: p |> rel |> lib.splitString "/";

  # Path-valued leaves, so `.#nixFiles.modules.services.zettel-graph` is the
  # file itself and can be handed to `imports = [ ... ]` unchanged.
  tree =
    files
    |> builtins.foldl' (acc: f: acc |> lib.recursiveUpdate (f |> segments |> (p: lib.setAttrByPath p f))) {};

  # The one naming rule for the import namespace (`.#modules`), used in both
  # directions: a chain writes the name, the walk reads it back to an edge.
  # `modules/profiles/base-node.nix` -> `profiles.base-node`; a file named after
  # its directory does not repeat the word, and `default.nix` is the directory:
  # `modules/global/global.nix` -> `global`, `modules/net/dns/default.nix` -> `net.dns`.
  moduleFiles = paths |> builtins.filter (p: p |> lib.hasPrefix "modules/");
  nameOf = p: let
    parts = p |> lib.removeSuffix ".nix" |> lib.removePrefix "modules/" |> lib.splitString "/";
    n = parts |> builtins.length;
    stem = parts |> lib.last;
  in
    if n > 1 && (stem == "default" || stem == builtins.elemAt parts (n - 2))
    then parts |> lib.init |> lib.concatStringsSep "."
    else parts |> lib.concatStringsSep ".";
  # `listToAttrs` keeps the last of a collision silently; `checks.<system>.nix-registry`
  # counts names against files and fails instead.
  # A PATH, not the relative string: `self.modules."x"` is handed straight to
  # `imports = [ ... ]`, and a relative string fails there with "doesn't represent
  # an absolute path". The walk keeps both: `byName` for consumers, `nameOf` for
  # the edges below.
  byPath =
    files
    |> map (f: {
      name = f |> rel;
      value = f;
    })
    |> builtins.listToAttrs;
  byName =
    moduleFiles
    |> map (p: {
      name = p |> nameOf;
      value = byPath.${p};
    })
    |> builtins.listToAttrs;

  normalisePath = path: let
    segs = path |> lib.splitString "/";
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
    segs |> builtins.foldl' step [] |> lib.concatStringsSep "/";

  pathTokens = text:
    text
    |> builtins.split "[^A-Za-z0-9_./-]+"
    |> builtins.filter (
      t:
        builtins.isString t
        && ((t |> lib.hasPrefix "./") || (t |> lib.hasPrefix "../"))
        && (t |> lib.hasSuffix ".nix")
    );

  # `self.modules."roles.home"` (and the unquoted form). Quoted names are the
  # convention; both are read so an edge cannot disappear because of the syntax.
  # Split on the prefix and read the name off the chunk that follows: a regex
  # capture here would also hand back the dotted segments.
  nameRefs = text: let
    # Comments name things too, and a name in prose is not an edge. Dropping them
    # also keeps an example in a header from looking like a real import.
    code = text |> lib.splitString "\n" |> map (l: l |> builtins.split "#" |> builtins.head) |> lib.concatStringsSep "\n";
    # Both vocabularies: a chain names a module as `moduleFiles."x"` before any
    # `self` exists, a module as `self.modules."x"`.
    chunks = code |> builtins.split ''self\.modules\.|moduleFiles\.'' |> builtins.filter builtins.isString;
    # The chunk runs to the end of the file; match against its first line only.
    # A whole-file `.*` pattern is a regex over tens of kilobytes and nix dumps
    # core on it (measured on the larger module files).
    refIn = chunk: let
      line = chunk |> builtins.split "\n" |> builtins.head;
      quoted = line |> builtins.match "\"([A-Za-z0-9_.-]+)\".*";
      bare = line |> builtins.match "([A-Za-z0-9_.-]+).*";
    in
      if quoted != null
      then quoted |> builtins.head
      else if bare != null
      then bare |> builtins.head
      else null;
  in
    if chunks == []
    then []
    else chunks |> builtins.tail |> map refIn |> builtins.filter (n: n != null);

  # `AGENTS.nix` is the note store: prose in a Nix string, not a config. A
  # module named there is being discussed, not imported, and counting it made
  # `ops:kg:module` report the note as an importer — and made a placeholder in a
  # design note read as a dangling name. One rule, used by the edges and by the
  # registry's dangling-name scan, so the two cannot disagree.
  nameRefsOf = p:
    if p == "AGENTS.nix"
    then []
    else root + "/${p}" |> builtins.readFile |> nameRefs;

  importsOf = p: let
    dir = dirOf p;
    text = root + "/${p}" |> builtins.readFile;
    targets =
      (
        text
        |> pathTokens
        |> map (
          t:
            (
              if dir == "."
              then t
              else "${dir}/${t}"
            )
            |> normalisePath
        )
      )
      ++ (p |> nameRefsOf |> builtins.filter (n: byName |> builtins.hasAttr n) |> map (n: byName.${n} |> rel));
  in
    targets |> builtins.filter (t: t != p) |> lib.unique;

  edges =
    paths
    |> map (p: {
      name = p;
      value = p |> importsOf;
    })
    |> builtins.listToAttrs;
  # A token only becomes an edge when it resolves to a file in `paths`; callers
  # filter, so a dangle is a missing edge rather than a phantom file.
  importsOfPath = p: edges.${p} or [];
in {
  inherit files paths tree edges importsOfPath;
  inherit moduleFiles nameOf byPath byName nameRefs nameRefsOf;
  relPath = rel;
  count = files |> builtins.length;
}
