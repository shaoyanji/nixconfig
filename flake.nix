{
  description = "
    ChromeOS and WSL (penguin + guckloch)
    Linux + Nix (heim)
    MacOS + Nix (cassini)
    NixOS (poseidon, ares, schneeeule, aceofspades, minyx)
    Asahi Linux (lunarfall)
    Arch Pi (alarm)
  ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
      inputs.nixpkgs.follows = "nix-darwin";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix/v0.4.1";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
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
  };

  outputs = {
    self,
    nix-darwin,
    nixpkgs,
    nix-homebrew,
    nixos-wsl,
    nixos-hardware,
    raspberry-pi-nix,
    home-manager,
    impermanence,
    disko,
    chaotic,
    sops-nix,
    nur,
    utils,
    ...
  } @ inputs: let
    hydenixConfig = inputs.hydenix.inputs.hydenix-nixpkgs.lib.nixosSystem {
      inherit (inputs.hydenix.lib) system;
      specialArgs = {
        inherit inputs;
      };
      modules = [
        ./hosts/poseidon/configuration2.nix
      ];
    };
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
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
        chaotic.nixosModules.default
        #lix-module.nixosModules.default
        nur.modules.nixos.default
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
  in {
    homeConfigurations = {
      root = home-manager.lib.homeManagerConfiguration {
        extraSpecialArgs = {inherit inputs;};
        pkgs = nixpkgs.legacyPackages."x86_64-linux";
        modules = [./modules/global/heim.nix];
      };
      jisifu = home-manager.lib.homeManagerConfiguration {
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
        modules = [./hosts/alarm.nix];
      };
      devji = home-manager.lib.homeManagerConfiguration {
        extraSpecialArgs = {inherit inputs;};
        pkgs = nixpkgs.legacyPackages."aarch64-linux";
        modules = [
          ./modules/global/heim.nix
        ];
      };
    };
    nixosConfigurations = {
      "poseidon" = hydenixConfig;

      # ${hydenixConfig.userConfig.host} = hydenixConfig.nixosConfiguration;

      #packages."x86_64-linux" = {
      #  default = hydenixConfig.nix-vm.config.system.build.vm;
      #};
      #
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
        modules =
          globalModulesNixos
          ++ [./hosts/aceofspades/configuration.nix];
      };
      ancientace =
        #nixpkgs.lib.nixosSystem {
        inputs.hydenix.inputs.hydenix-nixpkgs.lib.nixosSystem {
          inherit (inputs.hydenix.lib) system;
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./hosts/ancientace/configuration2.nix
          ];
        };
      # system = "x86_64-linux";
      #specialArgs = {inherit inputs;};
      #modules =
      #     globalModulesNixos
      #    ++ [
      #     inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t420
      #    ./hosts/ancientace/configuration.nix
      # ];
      #};
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
            /etc/nixos/configuration.nix
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
      coolbeans = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs;};
        modules =
          globalModulesContainers
          ++ [
            /etc/nixos/configuration.nix
          ];
      };
    };
    darwinConfigurations = {
      cassini = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = {inherit inputs;};
        modules =
          globalModulesMacos
          ++ [./hosts/cassini/configuration.nix];
      };
    };
    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations.cassini.pkgs;
  };
}
