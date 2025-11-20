{
  description = "
    Linux + Nix (heim)
    MacOS + Nix (cassini)
    NixOS (poseidon, ares, schneeeule, aceofspades, minyx, ancientace)
    ChromeOS and WSL (penguin + guckloch)
  ";

  inputs = {
    # determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    garnix-lib.url = "github:garnix-io/garnix-lib";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    caelestia = {
      url = "git+https://github.com/caelestia-dots/shell/";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kickstart-nixvim.url = "github:shaoyanji/kickstart.nixvim";
    kickstart-nixvim.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
  };

  outputs = {
    self,
    nix-index-database,
    nix-darwin,
    nixpkgs,
    nix-homebrew,
    nixos-wsl,
    home-manager,
    impermanence,
    disko,
    chaotic,
    sops-nix,
    nur,
    garnix-lib,
    caelestia,
    ...
  } @ inputs: let
    globalModules = [
      {
        system.configurationRevision = self.rev or self.dirtyRev or null;
      }
      ./modules/global/global.nix
    ];
    globalModulesNixos =
      globalModules
      ++ [
        ./modules/global/nixos.nix
        home-manager.nixosModules.default
        sops-nix.nixosModules.sops
        nur.modules.nixos.default
        chaotic.nixosModules.default
        nix-index-database.nixosModules.nix-index
        caelestia.packages
        #lix-module.nixosModules.default
        #determinate.nixosModules.default
      ];
    globalModulesImpermanence =
      globalModulesNixos
      ++ [
        ./modules/global/impermanence.nix
        impermanence.nixosModules.impermanence
        disko.nixosModules.default
      ];
    globalModulesMacos =
      globalModules
      ++ [
        ./modules/global/macos.nix
        nix-homebrew.darwinModules.nix-homebrew
        home-manager.darwinModules.default
        sops-nix.darwinModules.sops
      ];
    globalModulesContainers =
      globalModules
      ++ [
        ./modules/global/noDE.nix
        home-manager.nixosModules.default
        nix-index-database.nixosModules.nix-index
      ];
  in
    inputs.flake-utils.lib.eachDefaultSystem
    (
      system: let
        pkgs = import inputs.nixpkgs {inherit system;};
      in {
        packages = {
          #           frontend-bundle = pkgs.callPackage ./frontend { self = inputs.self; };
          backend = pkgs.callPackage ./modules/server/go-backend {};
        };
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.nodejs
            pkgs.go
            pkgs.gopls
          ];
        };
      }
    )
    // {
      homeConfigurations = {
        verntil = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = {inherit inputs;};
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          modules = [./hosts/verntil.nix];
        };
        root = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = {inherit inputs;};
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          modules = [./modules/global/heim.nix];
        };
        penguin = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = {inherit inputs;};
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          modules = [
            ./hosts/penguin.nix
            inputs.sops-nix.homeManagerModules.sops
          ];
        };
        alarm = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = {inherit inputs;};
          pkgs = nixpkgs.legacyPackages."aarch64-linux";
          modules = [
            ./hosts/alarm.nix
            inputs.sops-nix.homeManagerModules.sops
          ];
        };
        kali = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = {inherit inputs;};
          pkgs = nixpkgs.legacyPackages."aarch64-linux";
          modules = [./hosts/kali.nix];
        };
        devji = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = {inherit inputs;};
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          # pkgs = nixpkgs.legacyPackages."aarch64-linux";
          modules = [
            ./modules/global/heim.nix
          ];
        };
      };
      nixosConfigurations = {
        garnixMachine = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            garnix-lib.nixosModules.garnix
            {
              _module.args = {
                self = inputs.self;
              };
              # garnix.server.enable = true;
            }
            ./hosts/garnixMachine.nix
          ];
        };
        poseidon = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {inherit inputs;};
          modules =
            globalModulesNixos
            ++ [
              ./hosts/poseidon/configuration3.nix
            ];
        };

        mtfuji = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {inherit inputs;};
          modules =
            globalModulesContainers
            ++ [
              ./hosts/mtfuji/configuration.nix
              sops-nix.nixosModules.sops
            ];
        };
        applevalley = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {inherit inputs;};
          modules =
            globalModulesContainers
            ++ [
              inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t420
              ./hosts/applevalley/configuration.nix
              sops-nix.nixosModules.sops
            ];
        };
        thinsandy = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {inherit inputs;};
          modules =
            globalModulesContainers
            ++ [
              ./hosts/thinsandy/configuration.nix
              sops-nix.nixosModules.sops
            ];
        };
        ares = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {inherit inputs;};
          modules =
            globalModulesImpermanence
            ++ [
              ./hosts/ares/configuration.nix
              inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t440p
              (import ./hosts/common/disko.nix {device = "/dev/sda";})
            ];
        };
        schneeeule = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {inherit inputs;};
          modules =
            globalModulesImpermanence
            ++ [
              ./hosts/schneeeule/configuration.nix
              (import ./hosts/common/disko.nix {device = "/dev/sda";})
            ];
        };
        aceofspades = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {inherit inputs;};
          modules = globalModulesNixos ++ [./hosts/aceofspades/configuration.nix];
        };
        # ancientace = inputs.hydenix.inputs.hydenix-nixpkgs.lib.nixosSystem {
        #   inherit (inputs.hydenix.lib) system;
        #   specialArgs = {
        #     inherit inputs;
        #   };
        #   modules = [
        #     ./hosts/ancientace/configuration2.nix
        #   ];
        # };
        ancientace = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {inherit inputs;};
          modules = globalModulesNixos ++ [./hosts/ancientace/configuration3.nix];
        };
        minyx = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = {inherit inputs;};
          modules =
            globalModulesContainers
            ++ [
              ./hosts/minyx/configuration.nix
              ./hosts/minyx/custompi.nix
              sops-nix.nixosModules.sops
              impermanence.nixosModules.impermanence
              inputs.nixos-hardware.nixosModules.raspberry-pi-3
            ];
        };
        orb-cassini = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = {inherit inputs;};
          modules =
            globalModulesContainers
            ++ [
              ./hosts/orb-cassini/custom.nix
              ./hosts/orb-cassini/configuration.nix
              #/etc/nixos/configuration.nix
            ];
        };
        guckloch = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {inherit inputs;};
          modules =
            globalModulesContainers
            ++ [
              ./hosts/guckloch/configuration.nix
              nixos-wsl.nixosModules.default
            ];
        };
        #   coolbeans = nixpkgs.lib.nixosSystem {
        #     system = "x86_64-linux";
        #     specialArgs = {inherit inputs;};
        #     modules =
        #       globalModulesContainers
        #       ++ [
        #         /etc/nixos/configuration.nix
        #       ];
        #   };
      };
      darwinConfigurations = {
        cassini = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = {inherit inputs;};
          modules = globalModulesMacos ++ [./hosts/cassini/configuration.nix];
        };
      };
      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations.cassini.pkgs;
    };
}
