{
  description = "Working Darwin system flake using Determinate and SSL hack";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    nix-homebrew.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, 
		      home-manager, nixvim, sops-nix, ... }:
  let
    globalModules = [ 
      { 
        system.configurationRevision = self.rev or self.dirtyRev or null; 
      }
	./modules/global/global.nix 
    ];
    globalModulesNixos = globalModules ++ [ 
      ./modules/global/nixos.nix
      home-manager.nixosModules.default
    ];
    globalModulesMacos = globalModules ++ [ 
	./modules/global/macos.nix
	nix-homebrew.darwinModules.nix-homebrew
   	home-manager.darwinModules.default
    ];
  in
  {
    nixosConfigurations = {
      poseidon = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = globalModulesNixos
          ++ [ ./hosts/poseidon/configuration.nix ];
      };
    };
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#
    darwinConfigurations={
      cassini = nix-darwin.lib.darwinSystem {
	system = "aarch64-darwin";
	specialArgs = { inherit inputs; };
	modules = globalModulesMacos ++ [ 
	    ./hosts/cassini/configuration.nix
	];
      };
    };
    
    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations.cassini.pkgs;
  };
}
