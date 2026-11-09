# The Gravatar profile as data plus the one mail signature rendered from it; the
# TOML is the source of truth. Named in `.#modules` so himalaya's edge is
# followable, and read by `task gravatar:signature` so a preview cannot drift.
let
  profile = builtins.fromTOML (builtins.readFile ./gravatar.toml);

  # Third line is the site already named in the profile's own link list.
  site = let
    found = builtins.filter (link: link.label == "bountystash") profile.links;
  in
    if found == []
    then ""
    else builtins.replaceStrings ["https://"] [""] (builtins.head found).url;

  lines =
    [
      "${profile.first_name} ${profile.last_name}"
      "${profile.company} · ${profile.location}"
    ]
    ++ (
      if site == ""
      then []
      else [site]
    );
in {
  inherit profile;
  signature = builtins.concatStringsSep "\n" lines;
}
