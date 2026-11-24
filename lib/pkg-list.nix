# lib/pkg-list.nix — read a plain list of attribute names against `pkgs`.
# `#` starts a comment, whole-line or trailing, so a list can carry the reason
# next to the name. A name nixpkgs does not have throws: a typo cannot vanish.
{lib}: let
  trimR = s:
    s
    |> builtins.match "^(.*[^[:space:]])[[:space:]]*$"
    |> (m:
      if m == null
      then ""
      else m |> builtins.head);

  trim = s:
    s
    |> builtins.match "^[[:space:]]*(.*)$"
    |> (m:
      if m == null
      then ""
      else m |> builtins.head)
    |> trimR;

  # Everything from the first `#` is a comment. A nixpkgs attribute path cannot
  # contain `#`, so this is safe, and it is why uncommenting a line that carries
  # its rationale still parses. Split, not match: a lazy `(.*?)#.*` group left
  # the leading `#` of a `## heading` in the entry.
  stripComment = line: line |> lib.splitString "#" |> builtins.head;

  # `- helix`, `* helix`, `+ helix`; an ordered `1. helix` too.
  stripMarker = line: let
    bullet = line |> builtins.match "[[:space:]]*[-*+][[:space:]]+(.*)$";
    ordered = line |> builtins.match "[[:space:]]*[0-9]+[.)][[:space:]]+(.*)$";
  in
    if bullet != null
    then bullet |> builtins.head
    else if ordered != null
    then ordered |> builtins.head
    else line;

  # `- [x] helix` / `[ ]` — a checkbox is still just a marker.
  stripCheck = line:
    line
    |> builtins.match "[[]( |x|X)][[:space:]]+(.*)$"
    |> (m:
      if m == null
      then line
      else builtins.elemAt m 1);

  # Marker and checkbox can nest (`- [x] fd`), so unwrap twice: marker, box,
  # marker again. A single pass left `[x] fd` as an entry name.
  unmark = line: line |> stripMarker |> stripCheck |> stripMarker;

  clean = line: line |> stripComment |> unmark |> trim;

  # Ordered, de-duplicated entries. `lib.unique` keeps first occurrences.
  parse = text:
    text
    |> lib.splitString "\n"
    |> map clean
    |> builtins.filter (e: e != "")
    |> lib.unique;

  read = path: path |> builtins.readFile |> parse;

  # Dotted paths (`python3Packages.requests`) resolve through the package set,
  # so a list is not limited to top-level attributes.
  lookup = pkgs: name:
    name |> lib.splitString "." |> (p: lib.attrByPath p null pkgs);

  # A list may name things nixpkgs lacks; the leftovers come back by name instead
  # of failing the first one. Why: docs/pkg-list.md.
  split = {
    pkgs,
    path ? null,
    text ? null,
    origin ? null,
  }: let
    src =
      if text != null
      then text
      else if path != null
      then builtins.readFile path
      else throw "pkg-list.resolve: pass `path` or `text`";
    label =
      if origin != null
      then origin
      else if path != null
      then toString path
      else "<text>";
    entries = parse src;
    resolved =
      entries
      |> map (name: {
        inherit name;
        value = lookup pkgs name;
      });
  in {
    inherit label;
    packages = resolved |> builtins.filter (r: r.value != null) |> builtins.map (r: r.value);
    missing = resolved |> builtins.filter (r: r.value == null) |> builtins.map (r: r.name);
  };

  # Strict resolve: [ derivation ], throwing with the file and the entry, because
  # a declared package that silently vanishes is worse than a failed eval. Use
  # `split` when the list is not yours.
  resolve = args: let
    r = split args;
  in
    if r.missing == []
    then r.packages
    else
      throw ''
        pkg-list: these entries in ${r.label} are not nixpkgs attributes:
          ${r.missing |> lib.concatStringsSep "\n  "}
        Fix the attribute path, drop the line, or read the list with `split` and
        handle the leftovers yourself.'';
in {
  inherit parse read resolve split lookup;
}
