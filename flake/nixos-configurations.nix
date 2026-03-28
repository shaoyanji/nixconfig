{
  projectHosts,
  mkNixosHost,
}:
projectHosts "nixos" (_: host: mkNixosHost {
  inherit (host) system modules;
  specialArgs = host.specialArgs or {};
})
