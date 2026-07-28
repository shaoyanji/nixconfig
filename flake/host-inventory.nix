{
  inputs,
  moduleSets,
  self,
}: let
  inherit
    (moduleSets)
    globalModulesContainers
    globalModulesDemo
    globalModulesHome
    globalModulesImpermanence
    globalModulesMacos
    globalModulesNixos
    ;
in {
  garnixMachine = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = [
      inputs.garnix-lib.nixosModules.garnix
      ../hosts/garnixMachine.nix
    ];
  };

  poseidon = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = globalModulesNixos ++ [../hosts/poseidon/configuration.nix];
  };

  mtfuji = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = globalModulesContainers ++ [../hosts/mtfuji/configuration.nix];
  };

  kellerbench = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = globalModulesContainers ++ [../hosts/kellerbench/configuration.nix];
  };

  deckstation = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = globalModulesContainers ++ [../hosts/deckstation/configuration.nix];
  };

  applevalley = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules =
      globalModulesContainers
      ++ [
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t420
        ../hosts/applevalley/configuration.nix
      ];
  };

  frieren = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = globalModulesContainers ++ [../hosts/frieren/configuration.nix];
  };

  ares = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    # ares was a Lenovo T440p laptop until 2026-Q3; the SSD has been
    # moved into a desktop case (i5-6500, 8GB, GTX 750 Ti Kepler dGPU).
    # The T440p-specific nixos-hardware module is dropped here because
    # Lenovo-specific fan curves / power management don't apply to
    # desktop boards.  Impermanence chain is kept because the btrfs
    # /persist layout on /dev/sda is unchanged.
    modules =
      globalModulesImpermanence
      ++ [
        ../hosts/ares/configuration.nix
        (import ../hosts/common/disko.nix {device = "/dev/sda";})
      ];
  };

  schneeeule = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules =
      globalModulesImpermanence
      ++ [
        ../hosts/schneeeule/configuration.nix
        (import ../hosts/common/disko.nix {device = "/dev/sda";})
      ];
  };

  aristotle = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = globalModulesNixos ++ [../hosts/aristotle/configuration.nix];
  };

  netbook = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = globalModulesContainers ++ [
      ../hosts/netbook/configuration.nix
      inputs.disko.nixosModules.default
    ];
  };

  aceofspades = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = globalModulesNixos ++ [../hosts/aceofspades/configuration.nix];
  };

  ancientace = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = globalModulesNixos ++ [../hosts/ancientace/configuration.nix];
  };

  guckloch = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules =
      globalModulesContainers
      ++ [
        ../hosts/guckloch/configuration.nix
        inputs.nixos-wsl.nixosModules.default
      ];
  };

  minyx = {
    kind = "nixos";
    system = "aarch64-linux";
    specialArgs = {inherit inputs self;};
    modules =
      globalModulesContainers
      ++ [
        ../hosts/minyx/configuration.nix
        ../hosts/minyx/custompi.nix
        inputs.impermanence.nixosModules.impermanence
        inputs.nixos-hardware.nixosModules.raspberry-pi-3
      ];
  };

  sledgehammer = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = globalModulesContainers ++ [
      ../hosts/sledgehammer/configuration.nix
      inputs.disko.nixosModules.default
    ];
  };

  demo = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = globalModulesDemo ++ [../hosts/demo/configuration.nix];
  };

  testvm = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = [
      inputs.microvm.nixosModules.microvm
      (import ../hosts/microvms/testvm.nix {})
      ({pkgs, ...}: {
        environment.systemPackages = with pkgs; [
          vim
          htop
        ];
      })
    ];
  };

  penguin = {
    kind = "home";
    system = "x86_64-linux";
    extraSpecialArgs = {inherit inputs self;};
    modules = globalModulesHome ++ [../hosts/penguin.nix];
  };

  alarm = {
    kind = "home";
    system = "aarch64-linux";
    extraSpecialArgs = {inherit inputs self;};
    modules = globalModulesHome ++ [../hosts/alarm.nix];
  };

  kali = {
    kind = "home";
    system = "aarch64-linux";
    extraSpecialArgs = {inherit inputs self;};
    modules = globalModulesHome ++ [../hosts/kali.nix];
  };

  cassini = {
    kind = "darwin";
    system = "aarch64-darwin";
    specialArgs = {inherit inputs self;};
    modules = globalModulesMacos ++ [../hosts/cassini/configuration.nix];
  };
}
