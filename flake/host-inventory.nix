{
  inputs,
  moduleSets,
  self,
}: let
  inherit
    (moduleSets)
    globalModulesContainers
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

  thinsandy = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules = globalModulesContainers ++ [../hosts/thinsandy/configuration.nix];
  };

  ares = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules =
      globalModulesImpermanence
      ++ [
        ../hosts/ares/configuration.nix
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t440p
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
