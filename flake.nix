{
  description = "
    Linux + Nix (heim)
    MacOS + Nix (cassini)
    NixOS (poseidon, ares, schneeeule, aceofspades, minyx, ancientace)
    Arch Pi (alarm)
    ChromeOS and WSL (penguin + guckloch)
  ";

  inputs = {
    # determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    garnix-lib = {
      url = "github:garnix-io/garnix-lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # nixpkgs-legacy.url = "github:NixOS/nixpkgs/nixos-24.05";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    # secrets.url = "github:shaoyanji/secrets";
    # dotfiles.url = "github:shaoyanji/.dotfiles";
    # secrets.flake = false;
    # dotfiles.flake = false;
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix/v0.4.1";
    raspberry-pi-nix.inputs.nixpkgs.follows = "nixpkgs";
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
    nuenv = {
      url = "github:DeterminateSystems/nuenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland = {
      url = "github:hyprwm/hyprland";
      #  inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #hyprpaper = {
    #  url = "github:hyprwm/hyprpaper";
    #  inputs.hyprland.follows = "hyprland-plugins";
    #};
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    #    lix-module.url = "https://git.lix.systems/lix-project/nixos-module/archive/2.92.0.tar.gz";
    #    ghostty.url = "github:ghostty-org/ghostty";
    utils.url = "github:numtide/flake-utils";
    hydenix.url = "github:richen604/hydenix";
    quickshell = {
      # add ?ref=<tag> to track a tag
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # kickstart-nixvim.url = "git+file:///home/devji/nixconfig/modules/kickstart.nixvim";
    kickstart-nixvim.url = "github:shaoyanji/kickstart.nixvim";
  };

  outputs = {
    self,
    # determinate,
    nix-darwin,
    nixpkgs,
    # nixpkgs-legacy,
    nix-homebrew,
    nixos-wsl,
    # nixos-hardware,
    raspberry-pi-nix,
    home-manager,
    impermanence,
    disko,
    chaotic,
    sops-nix,
    nur,
    garnix-lib,
    # secrets,
    # utils,
    utils,
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
        # chaotic.nixosModules.default
        #lix-module.nixosModules.default
        nur.modules.nixos.default
        #determinate.nixosModules.default
      ];
    globalModulesImpermanence =
      globalModules
      ++ [
        ./modules/global/impermanence.nix
        nur.modules.nixos.default
        chaotic.nixosModules.default
        #lix-module.nixosModules.default
        sops-nix.nixosModules.sops
        home-manager.nixosModules.default
        impermanence.nixosModules.impermanence
        disko.nixosModules.default
      ];
    globalModulesMacos =
      globalModules
      ++ [
        ./modules/global/macos.nix
        nix-homebrew.darwinModules.nix-homebrew
        home-manager.darwinModules.default
      ];
    globalModulesContainers =
      globalModules
      ++ [
        ./modules/global/noDE.nix
        home-manager.nixosModules.default
      ];
  in
    inputs.utils.lib.eachDefaultSystem
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
      };

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
        poseidon = inputs.hydenix.inputs.hydenix-nixpkgs.lib.nixosSystem {
          inherit (inputs.hydenix.lib) system;
          specialArgs = {inherit inputs;};
          modules =
            globalModules
            ++ [
              ./hosts/poseidon/configuration2.nix
            ];
          # poseidon = nixpkgs.lib.nixosSystem {
          #   system = "x86_64-linux";
          #   specialArgs = {inherit inputs;};
          #   modules =
          #     globalModulesNixos
          #     ++ [
          #       ./hosts/poseidon/configuration3.nix
          #     ];
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
        ancientace = inputs.hydenix.inputs.hydenix-nixpkgs.lib.nixosSystem {
          inherit (inputs.hydenix.lib) system;
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./hosts/ancientace/configuration2.nix
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
