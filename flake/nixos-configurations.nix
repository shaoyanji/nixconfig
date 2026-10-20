{
  projectHosts,
  mkNixosHost,
  inputs,
  self,
}:
# Per-host specialArgs from host-inventory override the default
# { inherit inputs self; } (see lib/mk-nixos-host.nix).
projectHosts "nixos" (hostName: host:
    mkNixosHost {
      inherit hostName;
      inherit (host) system modules;
      specialArgs = host.specialArgs or {inherit inputs self;};
    })
