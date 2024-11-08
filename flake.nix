{
  description = "
  hyprland configuration
  Working Darwin system flake using Determinate and SSL hack
  ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs-stable";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    nix-homebrew.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    nuenv.url = "github:DeterminateSystems/nuenv";
    nuenv.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins.url = "github:hyprwm/hyprland-plugins";
    hyprland-plugins.inputs.hyprland.follows = "hyprland";
    hyprpaper = {
      url = "github:hyprwm/hyprpaper";
      inputs.hyprland.follows = "hyprland";
    };
  };

  outputs = { self, nix-darwin, nixpkgs, nix-homebrew, home-manager, nixvim, sops-nix, nuenv, hyprland,hyprland-plugins, hyprpaper, ... }@inputs:
  let
    overlays = [ inputs.nuenv.overlays.default ];
    systems= [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
      inherit system;
      pkgs = import nixpkgs { inherit overlays system; };
    });
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
    globalModulesHome = 
    #globalModules ++ 
    [ 
      ./modules/global/heim.nix
    ];
  in
  {
    homeConfigurations = {
      heim = home-manager.lib.homeManagerConfiguration {
        extraSpecialArgs = { inherit inputs; };
        pkgs = nixpkgs.legacyPackages."x86_64-linux";
        modules = globalModulesHome ++ [] ;
      };
    };
    nixosConfigurations = {
      poseidon = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
	      specialArgs = { inherit inputs; };
        modules = globalModulesNixos
          ++ [ ./hosts/poseidon/configuration.nix ];
      };
      aceofspades = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
	      specialArgs = { inherit inputs; };
        modules = globalModulesNixos
          ++ [ ./hosts/aceofspades/configuration.nix ];
      };
    };
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#
    darwinConfigurations={
      cassini = nix-darwin.lib.darwinSystem {
	    system = "aarch64-darwin";
	    specialArgs = { inherit inputs; };
        modules = globalModulesMacos
          ++ [ ./hosts/cassini/configuration.nix];
      };
    };
    
    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations.cassini.pkgs;
  };
}
