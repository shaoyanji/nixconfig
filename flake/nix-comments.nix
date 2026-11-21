# The comment budget as data: how many Nix comment lines carry prose rather than
# a pointer, and how many of those are a date. Both numbers only fall — a cleanup
# lowers one in the same commit, nothing raises one. Classifier and reader:
# `lib/nix-comments.nix`; gate `#nix-comments-are-pointers`.
{
  lib,
  paths,
}: let
  ceiling = 6486;
  datedCeiling = 140;
in
  (import ../lib/nix-comments.nix {inherit lib paths;})
  // {
    inherit ceiling datedCeiling;
  }
