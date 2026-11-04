# One cache decision per host in one file.
# Derives cache tier from inventory: LAN (harmonia), WAN (cachix), or CI anchor.
{lib}: let
  # URL + public key per cache, in lib/cache-registry.nix — the same file flake.nix
  # imports for its nixConfig. This file owns the per-host DECISION (which caches,
  # in what order); that one owns the addresses.
  registry = (import ./cache-registry.nix).caches;

  urlOf = names: map (n: registry.${n}.url) names;
  keysOf = names: map (n: registry.${n}.key) names;

  # `edge` sits immediately after `cachix` in both orders: the bucket is the
  # buffer for what cachix cannot hold, so a cachix hit always wins and the last
  # WAN tier is asked before the community/upstream ones. The overlap is empty by
  # construction anyway — `dev:nixcache:push` refuses to upload a path that
  # cachix or cache.nixos.org already has.
  lanOrder = ["harmonia" "cachix" "edge" "nixos" "numtide" "nixCommunity" "nixGaming" "determinate"];
  wanOrder = ["cachix" "edge" "nixos" "numtide" "nixCommunity" "determinate" "nixGaming"];

  # Two caches are declared by modules this tree imports, not by the list above:
  # nixpkgs' `nix` module appends cache.nixos.org with `mkAfter` on every host,
  # and `modules/global/determinate-nix.nix` declares DN's cache because DN's
  # binaries are not on cache.nixos.org. A host that also listed them got each
  # URL twice in `nix.conf` — invisible, and a second owner for one address.
  # They stay in the orders for VERIFICATION, which asks "could this path be
  # fetched" and must not care who declares the substituter.
  platformAppended = ["nixos" "determinate"];
  ownOrder = order: builtins.filter (n: !(builtins.elem n platformAppended)) order;

  # A `key = null` entry mirrors another cache and reuses its key, so the key list
  # is deduplicated rather than repeating frieren.lan-1 for the tailnet mirror.
  allKeys = lib.unique (builtins.filter (k: k != null) (keysOf (lib.attrNames registry)));

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
    substituters = urlOf (ownOrder available);
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
  inherit registry forHost lanOrder wanOrder platformAppended;

  # Convenience for callers holding the whole inventory.
  forHosts = hosts: lib.mapAttrs (_: forHost) hosts;
}
