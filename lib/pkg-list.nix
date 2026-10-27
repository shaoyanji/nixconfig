# lib/pkg-list.nix — read a plain list of attribute names against `pkgs`.
# `#` starts a comment, whole-line or trailing, so a list can carry the reason
# next to the name. A name nixpkgs does not have throws: a typo cannot vanish.
{lib}: let
  trimR = s: let
    m = builtins.match "^(.*[^[:space:]])[[:space:]]*$" s;
  in
    if m == null
    then ""
    else builtins.head m;

  trim = s: let
    m = builtins.match "^[[:space:]]*(.*)$" s;
  in
    trimR (
      if m == null
      then ""
      else builtins.head m
    );

  # Everything from the first `#` is a comment. A nixpkgs attribute path cannot
  # contain `#`, so this is safe, and it is why uncommenting a line that carries
  # its rationale still parses. Split, not match: a lazy `(.*?)#.*` group left
  # the leading `#` of a `## heading` in the entry.
  stripComment = line: builtins.head (lib.splitString "#" line);

  # `- helix`, `* helix`, `+ helix`; an ordered `1. helix` too.
  stripMarker = line: let
    bullet = builtins.match "[[:space:]]*[-*+][[:space:]]+(.*)$" line;
    ordered = builtins.match "[[:space:]]*[0-9]+[.)][[:space:]]+(.*)$" line;
  in
    if bullet != null
    then builtins.head bullet
    else if ordered != null
    then builtins.head ordered
    else line;

  # `- [x] helix` / `[ ]` — a checkbox is still just a marker.
  stripCheck = line: let
    m = builtins.match "[[]( |x|X)][[:space:]]+(.*)$" line;
  in
    if m == null
    then line
    else builtins.elemAt m 1;

  # Marker and checkbox can nest (`- [x] fd`), so unwrap twice: marker, box,
  # marker again. A single pass left `[x] fd` as an entry name.
  unmark = line: stripMarker (stripCheck (stripMarker line));

  clean = line: trim (unmark (stripComment line));

  # Ordered, de-duplicated entries. `lib.unique` keeps first occurrences.
  parse = text:
    lib.unique (
      builtins.filter (e: e != "")
      (map clean (lib.splitString "\n" text))
    );

  read = path: parse (builtins.readFile path);

  # Dotted paths (`python3Packages.requests`) resolve through the package set,
  # so a list is not limited to top-level attributes.
  lookup = pkgs: name:
    lib.attrByPath (lib.splitString "." name) null pkgs;

  # `{ pkgs, path }` or `{ pkgs, text }` -> `{ packages, missing }`. `origin` is
  # only for diagnostics (a path or a label).
  #
  # This is the honest half of the format: a list may name things nixpkgs does
  # not have — an upstream binary, an appimage, a wishlist line copied out of a
  # markdown handoff — and those have no attribute to resolve. Returning the
  # leftovers by name instead of dying on the first one is what makes ingesting
  # an untrusted list usable: you see the derivations AND the work still owed.
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
      map (name: {
        inherit name;
        value = lookup pkgs name;
      })
      entries;
  in {
    inherit label;
    packages = builtins.map (r: r.value) (builtins.filter (r: r.value != null) resolved);
    missing = builtins.map (r: r.name) (builtins.filter (r: r.value == null) resolved);
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
          ${lib.concatStringsSep "\n  " r.missing}
        Fix the attribute path, drop the line, or read the list with `split` and
        handle the leftovers yourself.'';
in {
  inherit parse read resolve split lookup;
}
