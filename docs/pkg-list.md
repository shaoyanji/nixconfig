# pkgs.txt and the lenient parse

`lib/pkg-list.nix` turns a human list into `{ packages, missing }`. `origin` is
diagnostics only (a path or a label).

A list may name things nixpkgs does not have: an upstream binary, an appimage, a
wishlist line copied out of a markdown handoff. Those have no attribute to
resolve, and returning the leftovers by name instead of dying on the first one
is what makes ingesting an untrusted list usable: you see the derivations and
the work still owed. The fixture in `flake/checks.nix` proves both halves.
