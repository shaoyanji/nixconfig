# fetches-extra — central registry for external fetched dependencies.
#
# Usage:
#   fetchesExtra = import ../lib/fetches-extra.nix { inherit pkgs; };
#   ariang = fetchesExtra.fetch "ariang";
#
# All registered entries live in modules/config/fetches.json.
# Update hashes: task dev:config:hash-update (runs nix-hash-update.sh).
{
  pkgs,
  fetchesJson ? ../modules/config/fetches.json,
}: let
  inherit (builtins) attrNames listToAttrs map readFile fromJSON;
  entries = fromJSON (readFile fetchesJson);

  metaKeys = ["key" "fetchType" "extraArgs"];

  index = listToAttrs (map (e: {
      name = e.key;
      value = e;
    }) entries);

  # Strip meta attrs so we can pass the rest to fetchurl/fetchzip directly.
  stripMeta =
    e:
    builtins.removeAttrs e (metaKeys
      ++ (if e ? extraArgs then attrNames e.extraArgs else []));
in rec {
  # Return the raw registry entry for a key.
  entry = key: index.${key};

  # Return a derivation or path for the given key.
  fetch = key: let
    e = entry key;
    args = stripMeta e // {name = e.key;} // (e.extraArgs or {});
  in
    if e.fetchType == "fetchzip" then pkgs.fetchzip args
    else if e.fetchType == "fetchurl" then pkgs.fetchurl args
    else throw "Unknown fetchType '${e.fetchType}' for key '${key}'";
}
