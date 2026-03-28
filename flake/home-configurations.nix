{
  projectHosts,
  inputs,
  nixpkgs,
}:
projectHosts "home" (_: host: inputs.home-manager.lib.homeManagerConfiguration {
  extraSpecialArgs = host.extraSpecialArgs or {};
  pkgs = nixpkgs.legacyPackages.${host.system};
  inherit (host) modules;
})
