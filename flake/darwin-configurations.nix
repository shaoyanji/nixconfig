{
  projectHosts,
  inputs,
  self,
}:
# Per-host specialArgs from host-inventory override the default
# { inherit inputs self; } — same default as lib/mk-nixos-host.nix.
projectHosts "darwin" (_: host:
inputs.nix-darwin.lib.darwinSystem {
  inherit (host) system modules;
  specialArgs = host.specialArgs or {inherit inputs self;};
})
