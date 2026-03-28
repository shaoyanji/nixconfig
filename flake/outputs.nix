{
  inputs,
  self,
  nixpkgs,
}: let
  lib = nixpkgs.lib;
  systems = import ./systems.nix {flake-utils = inputs.flake-utils;};
  pkgsFor = import ./pkgs-for.nix {inherit nixpkgs;};
  mkNixosHost = import ../lib/mk-nixos-host.nix {inherit nixpkgs;};
  moduleSets = import ./module-sets.nix {inherit inputs self;};
  hostInventory = import ./host-inventory.nix {inherit inputs moduleSets self;};
  hostProjection = import ./host-projection.nix {inherit lib hostInventory;};
  projectHosts = hostProjection.project;
in
{
  packages = import ./packages.nix {
    inherit lib systems pkgsFor;
  };

  checks = import ./checks.nix {
    inherit lib systems pkgsFor self;
  };

  devShells = import ./devshells.nix {
    inherit lib systems pkgsFor;
  };

  homeConfigurations = import ./home-configurations.nix {
    inherit inputs nixpkgs projectHosts;
  };

  nixosConfigurations = import ./nixos-configurations.nix {
    inherit mkNixosHost projectHosts;
  };

  darwinConfigurations = import ./darwin-configurations.nix {
    inherit inputs projectHosts;
  };

  # Expose the package set, including overlays, for convenience.
  darwinPackages = self.darwinConfigurations.cassini.pkgs;

  docsSite = (pkgsFor "x86_64-linux").callPackage ../docs-site/default.nix {};
  docs-site = self.docsSite;

  hostProjection = hostProjection;
}
