# One cache decision per host in one file.
# Derives cache tier from inventory: LAN (harmonia), WAN (cachix), or CI anchor.
{lib}: let
  registry = {
    harmonia = {
      url = "http://192.168.3.25:5000";
      key = "frieren.lan-1:BUg+1UmfYlF0XCbC0+ZyWQOY1DpQJhj/wa2q76NTFOg=";
      role = "lan";
    };
    cachix = {
      url = "https://shaoyanji.cachix.org";
      key = "shaoyanji.cachix.org-1:3XUZGFcaq5bXFKwtCR+POG81Hh6WfTqf50Bmz4VHpj0=";
      role = "wan";
    };
    nixos = {
      url = "https://cache.nixos.org/";
      key = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
      role = "upstream";
    };
    numtide = {
      url = "https://cache.numtide.com";
      key = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
      role = "upstream";
    };
    nixCommunity = {
      url = "https://nix-community.cachix.org";
      key = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
      role = "community";
    };
    nixGaming = {
      url = "https://nix-gaming.cachix.org";
      key = "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=";
      role = "community";
    };
    determinate = {
      url = "https://install.determinate.systems";
      key = "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM=";
      role = "upstream";
    };
  };

  urlOf = names: map (n: registry.${n}.url) names;
  keysOf = names: map (n: registry.${n}.key) names;

  lanOrder = ["harmonia" "cachix" "nixos" "numtide" "nixCommunity" "nixGaming" "determinate"];
  wanOrder = ["cachix" "nixos" "numtide" "nixCommunity" "determinate" "nixGaming"];

  allKeys = keysOf (lib.attrNames registry);

  # A host's policy. `category` is the only input, and it is the inventory's fact,
  # not a judgement made again in a script.
  forHost = host: let
    cloud = (host.category or "") == "cloud";
    # LAN first for a LAN host (gigabit, no WAN cost); never for a cloud host.
    available =
      if cloud
      then wanOrder
      else lanOrder;
  in {
    tier =
      if cloud
      then "wan"
      else "lan";
    substituters = urlOf available;
    trustedSubstituters = urlOf (lib.attrNames registry);
    trustedKeys = allKeys;
    # Where this host's closure is expected to be warmed, and by whom.
    warmOn =
      if cloud
      then "self"
      else "harmonia";
    # A cloud host is not a warm target for the NAS: it builds natively and pushes
    # from its own uplink.
    warmableLocally = !cloud;
    verifyStores =
      if cloud
      then urlOf wanOrder
      else urlOf ["harmonia" "cachix"];
    # The cache a deploy on this host may pull a closure from.
    deployStores =
      if cloud
      then urlOf wanOrder
      else urlOf (["harmonia"] ++ wanOrder);
  };
in {
  inherit registry forHost lanOrder wanOrder;

  # Convenience for callers holding the whole inventory.
  forHosts = hosts: lib.mapAttrs (_: forHost) hosts;
}
