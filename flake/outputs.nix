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
in {
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
    inherit lib inputs hostInventory nixpkgs;
  };

  nixosConfigurations = import ./nixos-configurations.nix {
    inherit lib mkNixosHost hostInventory;
  };

  darwinConfigurations = import ./darwin-configurations.nix {
    inherit lib inputs hostInventory;
  };

  # Expose the package set, including overlays, for convenience.
  darwinPackages = self.darwinConfigurations.cassini.pkgs;
}
