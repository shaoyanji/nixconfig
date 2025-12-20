{
  description = "
    Linux + Nix (heim)
    MacOS + Nix (cassini)
    NixOS (poseidon, ares, schneeeule, applevalley, mtfuji, ancientace)
    NixOS HomeServer (thinsandy)
    aarch64 hm (kali)
    aarch NixOS (minyx)
    ChromeOS (penguin)
    WSL (guckloch)
  ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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
    # caelestia = {
    #   url = "git+https://github.com/caelestia-dots/shell/";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    kickstart-nixvim.url = "github:shaoyanji/kickstart.nixvim";
    kickstart-nixvim.inputs.nixpkgs.follows = "nixpkgs";
    garnix-lib.url = "github:garnix-io/garnix-lib";
    # nixgl.url = "github:nix-community/nixGL";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    dgop = {
      url = "github:AvengeMedia/dgop";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
      # inputs.dgop.follows = "dgop";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nix-index-database,
    nixpkgs,
    home-manager,
    impermanence,
    disko,
    chaotic,
    sops-nix,
    nur,
    garnix-lib,
    # nixgl,
    nix-darwin,
    nix-homebrew,
    nixos-wsl,
    kickstart-nixvim,
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
        inputs.niri.nixosModules.niri
        inputs.dms.nixosModules.dankMaterialShell
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
        sops-nix.nixosModules.sops
        home-manager.nixosModules.default
        chaotic.nixosModules.default
        nix-index-database.nixosModules.nix-index
      ];
    globalModulesHome = [
      kickstart-nixvim.homeManagerModules.default
      sops-nix.homeManagerModules.sops
      nix-index-database.homeModules.nix-index
    ];
  in
    inputs.flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};
      in {
        packages = {
          # frontend-bundle = pkgs.callPackage ./frontend {self = inputs.self;};
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
        penguin = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = {inherit inputs;};
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          modules =
            globalModulesHome
            ++ [
              ./hosts/penguin.nix
            ];
        };
        alarm = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = {inherit inputs;};
          pkgs = nixpkgs.legacyPackages."aarch64-linux";
          modules =
            globalModulesHome
            ++ [
              ./hosts/alarm.nix
            ];
        };
        kali = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = {inherit inputs;};
          pkgs = nixpkgs.legacyPackages."aarch64-linux";
          modules =
            globalModulesHome
            ++ [
              ./hosts/kali.nix
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
            ];
        };
        thinsandy = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {inherit inputs;};
          modules =
            globalModulesContainers
            ++ [
              ./hosts/thinsandy/configuration.nix
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
        minyx = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = {inherit inputs;};
          modules =
            globalModulesContainers
            ++ [
              ./hosts/minyx/configuration.nix
              ./hosts/minyx/custompi.nix
              impermanence.nixosModules.impermanence
              inputs.nixos-hardware.nixosModules.raspberry-pi-3
            ];
        };
        # orb-cassini = nixpkgs.lib.nixosSystem {
        #   system = "aarch64-linux";
        #   specialArgs = {inherit inputs;};
        #   modules =
        #     globalModulesContainers
        #     ++ [
        #       ./hosts/orb-cassini/custom.nix
        #       ./hosts/orb-cassini/configuration.nix
        #       #/etc/nixos/configuration.nix
        #     ];
        # };
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
