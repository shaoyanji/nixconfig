{ inputs
, moduleSets
, self
,
}:
let
  inherit
    (moduleSets)
    globalModulesContainers
    globalModulesDemo
    globalModulesHome
    globalModulesImpermanence
    globalModulesMacos
    globalModulesNixos
    ;
in
{
  garnixMachine = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
    modules = [
      inputs.garnix-lib.nixosModules.garnix
      ../hosts/garnixMachine.nix
    ];
  };

  poseidon = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
    modules = globalModulesNixos ++ [ ../hosts/poseidon/configuration.nix ];
  };

  mtfuji = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
    modules = globalModulesContainers ++ [ ../hosts/mtfuji/configuration.nix ];
  };

  kellerbench = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
    modules = globalModulesContainers ++ [ ../hosts/kellerbench/configuration.nix ];
  };

  deckstation = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
    modules = globalModulesContainers ++ [ ../hosts/deckstation/configuration.nix ];
  };
  eisen = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
    # Upgraded from a cage-based Steam kiosk to a full desktop
    # (poseidon-style): globalModulesNixos brings in niri + DankMaterialShell
    # and the sops/nix-index HM modules.  Steam runs under the upstream
    # gamescope-session (safe on the RX 5700's modern Vulkan ICD, unlike
    # kellerbench's Kepler card).  The previous cage-kiosk specialisation and
    # greetd dual-session experiments hung at graphical.target, so the DMS
    # greeter path (as on poseidon) is used instead of greetd auto-login.
    modules = globalModulesNixos ++ [ ../hosts/eisen/configuration.nix ];
  };

  applevalley = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
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
    specialArgs = { inherit inputs self; };
    modules = globalModulesNixos ++ [ ../hosts/frieren/configuration.nix ];
  };

  ares = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
    # ares is the T440p SSD moved into a desktop case (i5-6500 + GTX
    # 750 Ti).  Converted to a Steam Big Picture kiosk (steamos.nix)
    # mirroring eisen/kellerbench.  Uses the noDE containers chain +
    # impermanence (root wiped each boot; devji home + /etc persisted
    # to /persist).  The T440p-specific nixos-hardware module is
    # dropped because Lenovo fan curves / power management do not
    # apply to desktop boards.  The btrfs /persist layout on /dev/sda
    # is unchanged (disko).
    modules =
      globalModulesContainers
      ++ [
        inputs.impermanence.nixosModules.impermanence
        inputs.disko.nixosModules.default
        ../modules/global/impermanence.nix
        ../hosts/ares/configuration.nix
        (import ../hosts/common/disko.nix { device = "/dev/sda"; })
      ];
  };

  schneeeule = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
    modules =
      globalModulesImpermanence
      ++ [
        ../hosts/schneeeule/configuration.nix
        (import ../hosts/common/disko.nix { device = "/dev/sda"; })
      ];
  };

  scratch = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
    # Lightweight niri desktop (eisen-style) on a Fujitsu ESPRIMO D556
    # (i5-6500, 8 GB RAM, 128 GB f2fs SSD). Formerly a Steam Remote
    # Play kiosk; Steam dropped in the 2026-09 desktop conversion.
    # f2fs has no subvolumes so the btrfs impermanence module is NOT
    # used — the host config puts every heavy-write dir on tmpfs
    # (zram 100%, journald volatile, fstrim, noatime).  Legacy BIOS
    # boot: GRUB on /dev/sda, systemd-boot disabled.
    modules = globalModulesNixos ++ [ ../hosts/scratch/configuration.nix ];
  };

  aristotle = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
    modules = globalModulesNixos ++ [ ../hosts/aristotle/configuration.nix ];
  };

  netbook = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
    modules =
      globalModulesContainers
      ++ [
        ../hosts/netbook/configuration.nix
        inputs.disko.nixosModules.default
      ];
  };

  aceofspades = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
    modules = globalModulesNixos ++ [ ../hosts/aceofspades/configuration.nix ];
  };

  ancientace = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
    modules = globalModulesNixos ++ [ ../hosts/ancientace/configuration.nix ];
  };

  guckloch = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
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
    specialArgs = { inherit inputs self; };
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
    specialArgs = { inherit inputs self; };
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
    specialArgs = { inherit inputs self; };
    modules = globalModulesDemo ++ [ ../hosts/demo/configuration.nix ];
  };

  testvm = {
    kind = "nixos";
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
    modules = [
      inputs.microvm.nixosModules.microvm
      (import ../hosts/microvms/testvm.nix { })
      ({ pkgs, ... }: {
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
    extraSpecialArgs = { inherit inputs self; };
    modules = globalModulesHome ++ [ ../hosts/penguin.nix ];
  };

  alarm = {
    kind = "home";
    system = "aarch64-linux";
    extraSpecialArgs = { inherit inputs self; };
    modules = globalModulesHome ++ [ ../hosts/alarm.nix ];
  };

  kali = {
    kind = "home";
    system = "aarch64-linux";
    extraSpecialArgs = { inherit inputs self; };
    modules = globalModulesHome ++ [ ../hosts/kali.nix ];
  };

  cassini = {
    kind = "darwin";
    system = "aarch64-darwin";
    specialArgs = { inherit inputs self; };
    modules = globalModulesMacos ++ [ ../hosts/cassini/configuration.nix ];
  };
}
