{
  description = "
  chromeos and arch home configuration
  hyprland configuration
  Working Darwin system flake using Determinate and SSL hack
  ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    impermanence.url = "github:nix-community/impermanence";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    nix-homebrew.inputs.nixpkgs.follows = "nix-darwin";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    nuenv.url = "github:DeterminateSystems/nuenv";
    nuenv.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "github:hyprwm/hyprland";
    hyprland-plugins.url = "github:hyprwm/hyprland-plugins";
    hyprland-plugins.inputs.hyprland.follows = "hyprland";
    #  hyprpaper = {
    #  url = "github:hyprwm/hyprpaper";
    #  inputs.hyprland.follows = "hyprland-plugins";
    #};
    zen-browser.url = "github:MarceColl/zen-browser-flake";
  };

  outputs = { self, nix-darwin, nixpkgs, nix-homebrew, nixos-wsl, home-manager, chaotic, nixvim, sops-nix, nuenv, hyprland,hyprland-plugins,
    zen-browser,
    ... }@inputs:
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
    globalModulesImpermanence = globalModules ++ [
      ./modules/global/impermanence.nix
      home-manager.nixosModules.default
      inputs.impermanence.nixosModules.default
      inputs.disko.nixosModules.default
    ];
    globalModulesMacos = globalModules ++ [ 
      ./modules/global/macos.nix
      nix-homebrew.darwinModules.nix-homebrew
      home-manager.darwinModules.default
    ];
  in
  {
    homeConfigurations = {
      heim = home-manager.lib.homeManagerConfiguration {
        extraSpecialArgs = { inherit inputs; };
        pkgs = nixpkgs.legacyPackages."x86_64-linux";
        modules = [./modules/global/heim.nix
          ] ;
      };
      penguin = home-manager.lib.homeManagerConfiguration {
        extraSpecialArgs = { inherit inputs; };
        pkgs = nixpkgs.legacyPackages."x86_64-linux";
        modules = [./modules/global/penguin.nix] ;
      };
      alarm = home-manager.lib.homeManagerConfiguration {
        extraSpecialArgs = { inherit inputs; };
        pkgs = nixpkgs.legacyPackages."aarch64-linux";
        modules = [./modules/global/alarm.nix] ;
      };
      lunarfall = home-manager.lib.homeManagerConfiguration {
        extraSpecialArgs = { inherit inputs; };
        pkgs = nixpkgs.legacyPackages. "aarch64-linux";
        modules = [./modules/global/lunarfall.nix] ;
      };
    };
    nixosConfigurations = {
      poseidon = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = globalModulesNixos
          ++ [ ./hosts/poseidon/configuration.nix 
            chaotic.nixosModules.default
            ];
      };
      ares = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = globalModulesImpermanence
          ++ [ ./hosts/ares/configuration.nix 
            chaotic.nixosModules.default
            (import ./hosts/disko.nix { device = "/dev/sda"; })
            ];
      };
      schneeeule = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = globalModulesImpermanence
          ++ [ ./hosts/schneeeule/configuration.nix 
            chaotic.nixosModules.default
            (import ./hosts/disko.nix { device = "/dev/sda"; })
            ];
      };

      aceofspades = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = globalModulesNixos
          ++ [ ./hosts/aceofspades/configuration.nix ];
      };
      guckloch = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = globalModulesNixos
          ++ [ ./hosts/guckloch/configuration.nix 
          nixos-wsl.nixosModules.default
            {
              system.stateVersion = "24.05";
              wsl.enable = true;
            }
          ];

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
