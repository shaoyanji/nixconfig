# The Gravatar profile as data, plus the one plain-text signature rendered from
# it. `modules/config/gravatar.toml` is the source of truth; himalaya and
# `task gravatar:signature` both read this file, so a preview cannot drift from
# what outgoing mail carries.
let
  profile = builtins.fromTOML (builtins.readFile ../modules/config/gravatar.toml);

  # The signature's third line is the site in the profile's own link list, so
  # the address is written once. A missing entry drops the line instead of
  # failing the whole host eval.
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
