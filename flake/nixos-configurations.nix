{
  inputs,
  self,
  mkNixosHost,
  moduleSets,
}: let
  inherit
    (moduleSets)
    globalModulesContainers
    globalModulesImpermanence
    globalModulesNixos
    ;
in {
  garnixMachine = mkNixosHost {
    system = "x86_64-linux";
    modules = [
      inputs.garnix-lib.nixosModules.garnix
      {
        _module.args = {
          self = inputs.self;
        };
      }
      ../hosts/garnixMachine.nix
    ];
  };

  poseidon = mkNixosHost {
    system = "x86_64-linux";
    specialArgs = {inherit inputs self;};
    modules =
      globalModulesNixos
      ++ [
        ../hosts/poseidon/configuration3.nix
      ];
  };

  mtfuji = mkNixosHost {
    system = "x86_64-linux";
    specialArgs = {inherit inputs;};
    modules =
      globalModulesContainers
      ++ [
        ../hosts/mtfuji/configuration.nix
      ];
  };

  applevalley = mkNixosHost {
    system = "x86_64-linux";
    specialArgs = {inherit inputs;};
    modules =
      globalModulesContainers
      ++ [
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t420
        ../hosts/applevalley/configuration.nix
      ];
  };

  thinsandy = mkNixosHost {
    system = "x86_64-linux";
    specialArgs = {inherit inputs;};
    modules =
      globalModulesContainers
      ++ [
        ../hosts/thinsandy/configuration.nix
      ];
  };

  ares = mkNixosHost {
    system = "x86_64-linux";
    specialArgs = {inherit inputs;};
    modules =
      globalModulesImpermanence
      ++ [
        ../hosts/ares/configuration.nix
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t440p
        (import ../hosts/common/disko.nix {device = "/dev/sda";})
      ];
  };

  schneeeule = mkNixosHost {
    system = "x86_64-linux";
    specialArgs = {inherit inputs;};
    modules =
      globalModulesImpermanence
      ++ [
        ../hosts/schneeeule/configuration.nix
        (import ../hosts/common/disko.nix {device = "/dev/sda";})
      ];
  };

  aceofspades = mkNixosHost {
    system = "x86_64-linux";
    specialArgs = {inherit inputs;};
    modules = globalModulesNixos ++ [../hosts/aceofspades/configuration.nix];
  };

  ancientace = mkNixosHost {
    system = "x86_64-linux";
    specialArgs = {inherit inputs;};
    modules = globalModulesNixos ++ [../hosts/ancientace/configuration3.nix];
  };

  guckloch = mkNixosHost {
    system = "x86_64-linux";
    specialArgs = {inherit inputs;};
    modules =
      globalModulesContainers
      ++ [
        ../hosts/guckloch/configuration.nix
        inputs.nixos-wsl.nixosModules.default
      ];
  };

  minyx = mkNixosHost {
    system = "aarch64-linux";
    specialArgs = {inherit inputs;};
    modules =
      globalModulesContainers
      ++ [
        ../hosts/minyx/configuration.nix
        ../hosts/minyx/custompi.nix
        inputs.impermanence.nixosModules.impermanence
        inputs.nixos-hardware.nixosModules.raspberry-pi-3
      ];
  };

  testvm = mkNixosHost {
    system = "x86_64-linux";
    specialArgs = {inherit inputs;};
    modules = [
      inputs.microvm.nixosModules.microvm
      ../hosts/microvms/testvm.nix
    ];
  };
}
