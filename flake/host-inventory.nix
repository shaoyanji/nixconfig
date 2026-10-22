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
    # The microVM hosts below build their own module list instead of using a
    # global chain, so they take the inventory injection explicitly. Without it
    # they have no `config.fleet.inventory`; `checks.<system>.inventory-modules`
    # catches that structurally (no host evaluation) and
    # `task checks:host:HOST=<host>` catches it behaviourally.
    inventoryModules
    ;
in {
  garnixMachine = {
    kind = "nixos";
    system = "x86_64-linux";
    modules =
      inventoryModules
      ++ [
        inputs.garnix-lib.nixosModules.garnix
        ../hosts/garnixMachine.nix
      ];
  };

  poseidon = {
    kind = "nixos";
    system = "x86_64-linux";
    modules = globalModulesNixos ++ [../hosts/poseidon/configuration.nix];
  };

  mtfuji = {
    kind = "nixos";
    system = "x86_64-linux";
    modules = globalModulesContainers ++ [../hosts/mtfuji/configuration.nix];
  };

  kellerbench = {
    kind = "nixos";
    system = "x86_64-linux";
    modules = globalModulesContainers ++ [../hosts/kellerbench/configuration.nix];
  };

  deckstation = {
    kind = "nixos";
    system = "x86_64-linux";
    modules = globalModulesContainers ++ [../hosts/deckstation/configuration.nix];
  };

  # Role/hardware/history are COMPILED, not commented: inventory.toml
  # `[hosts.delphi] notes`, surfaced by `task dev:inventory:feed`.
  delphi = {
    kind = "nixos";
    system = "aarch64-linux";
    modules =
      globalModulesContainers
      ++ [
        inputs.disko.nixosModules.default
        ../hosts/delphi/configuration.nix
        # Install-time layout (disko also owns delphi's fileSystems). OCI
        # paravirtualized boot volumes enumerate as /dev/sda; verify with
        # `lsblk` on the instance BEFORE the first nixos-anywhere run — disko
        # wipes the device it is given.
        (import ../hosts/delphi/disko.nix {device = "/dev/sda";})
      ];
  };
  eisen = {
    kind = "nixos";
    system = "x86_64-linux";
    # Role/hardware/history are COMPILED, not commented: inventory.toml
    # `[hosts.eisen] notes`, surfaced by `task dev:inventory:feed`.
    modules = globalModulesNixos ++ [../hosts/eisen/configuration.nix];
  };

  applevalley = {
    kind = "nixos";
    system = "x86_64-linux";
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
    modules = globalModulesNixos ++ [../hosts/frieren/configuration.nix];
  };

  ares = {
    kind = "nixos";
    system = "x86_64-linux";
    # Role/hardware/history are COMPILED, not commented: inventory.toml
    # `[hosts.ares] notes`, surfaced by `task dev:inventory:feed`.
    modules =
      globalModulesContainers
      ++ [
        inputs.impermanence.nixosModules.impermanence
        inputs.disko.nixosModules.default
        ../modules/global/impermanence.nix
        ../hosts/ares/configuration.nix
        (import ../hosts/common/disko.nix {device = "/dev/sda";})
      ];
  };

  stark = {
    kind = "nixos";
    system = "x86_64-linux";
    # Role/hardware/history are COMPILED, not commented: inventory.toml
    # `[hosts.stark] notes`, surfaced by `task dev:inventory:feed`.
    modules =
      globalModulesNixos
      ++ [
        inputs.disko.nixosModules.default
        ../hosts/stark/configuration.nix
        (import ../hosts/stark/disko.nix {
          mainDevice = "/dev/disk/by-id/ata-SK_hynix_SC311_SATA_128GB_MS83N428510303B5B";
          hddDevice = "/dev/disk/by-id/ata-ST1000LM035-1RK172_WL14QR63";
        })
      ];
  };

  fern = {
    kind = "nixos";
    system = "x86_64-linux";
    # Role/hardware/history are COMPILED, not commented: inventory.toml
    # `[hosts.fern] notes`, surfaced by `task dev:inventory:feed`.
    modules =
      globalModulesNixos
      ++ [
        inputs.disko.nixosModules.default
        ../hosts/fern/configuration.nix
        (import ../hosts/fern/disko.nix {device = "/dev/nvme0n1";})
      ];
  };

  schneeeule = {
    kind = "nixos";
    system = "x86_64-linux";
    modules =
      globalModulesImpermanence
      ++ [
        ../hosts/schneeeule/configuration.nix
        (import ../hosts/common/disko.nix {device = "/dev/sda";})
      ];
  };

  scratch = {
    kind = "nixos";
    system = "x86_64-linux";
    # Role/hardware/history are COMPILED, not commented: inventory.toml
    # `[hosts.scratch] notes`, surfaced by `task dev:inventory:feed`.
    modules = globalModulesNixos ++ [../hosts/scratch/configuration.nix];
  };

  aristotle = {
    kind = "nixos";
    system = "x86_64-linux";
    modules = globalModulesNixos ++ [../hosts/aristotle/configuration.nix];
  };

  # netbook is the fleet's one PINNED host: it builds from `inputs.nixpkgs_25_11`
  # (the exact revision it boots, 25.11.12484.b6018f87da91) instead of the
  # flake's unstable nixpkgs, and carries no global module chain — its own
  # configuration is the whole system. The pin is what makes it a flake host at
  # all: same revision ⇒ the same kernel and initrd store paths it already runs,
  # so a deploy cannot touch the boot chain that newer kernels broke here.
  netbook = {
    kind = "nixos";
    system = "x86_64-linux";
    nixpkgs = inputs.nixpkgs_25_11;
    # Its own configuration is the whole system, so it takes the compiled-inventory
    # injection explicitly — the same reason the microVM hosts above do. Without it
    # the host has no `config.fleet.inventory`, which `checks.<system>.inventory-modules`
    # rejects structurally and `hostChecks` rejects when it reads the registry.
    modules = inventoryModules ++ [../hosts/netbook/configuration.nix];
  };

  aceofspades = {
    kind = "nixos";
    system = "x86_64-linux";
    modules = globalModulesNixos ++ [../hosts/aceofspades/configuration.nix];
  };

  ancientace = {
    kind = "nixos";
    system = "x86_64-linux";
    modules = globalModulesNixos ++ [../hosts/ancientace/configuration.nix];
  };

  guckloch = {
    kind = "nixos";
    system = "x86_64-linux";
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
    modules =
      globalModulesContainers
      ++ [
        ../hosts/sledgehammer/configuration.nix
        inputs.disko.nixosModules.default
      ];
  };

  demo = {
    kind = "nixos";
    system = "x86_64-linux";
    modules = globalModulesDemo ++ [../hosts/demo/configuration.nix];
  };

  testvm = {
    kind = "nixos";
    system = "x86_64-linux";
    modules =
      inventoryModules
      ++ [
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

  frieren-canary = {
    kind = "nixos";
    system = "x86_64-linux";
    modules =
      inventoryModules
      ++ [
        inputs.microvm.nixosModules.microvm
        ../hosts/microvms/frieren-canary.nix
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
    modules = globalModulesMacos ++ [../hosts/cassini/configuration.nix];
  };
}
