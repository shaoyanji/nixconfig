{
  projectHosts,
  inputs,
}:
projectHosts "darwin" (_: host: inputs.nix-darwin.lib.darwinSystem {
  inherit (host) system modules;
  specialArgs = host.specialArgs or {};
})
