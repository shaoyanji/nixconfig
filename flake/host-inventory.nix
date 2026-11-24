{
  inputs,
  self,
  # Names for the module files a host adds outside a chain
  # (flake/nix-registry.nix). A host's own config stays a path: it is not under
  # modules/ and no other host imports it.
  moduleFiles,
}:
# A host is `features` (its chain, as data) plus `modules` (its own
# additions). Composing the list is the consumer's job —
# `moduleSets.hostModules` — so editing one host's feature list lands on
# that host alone; the shared `globalModules*` names are docs projections,
# not something a host composes from.
{
  garnixMachine = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["inventory"];
    modules = [
      inputs.garnix-lib.nixosModules.garnix
      ../hosts/garnixMachine.nix
    ];
  };

  poseidon = {
    kind = "nixos";
    system = "x86_64-linux";
    # The fleet desktop chain. The host imports base-desktop-environment itself;
    # the Ryoku tier it ran from 2026-11-02 to 2026-11-11 is retired.
    features = ["base" "nixos" "dms"];
    hmFeatures = ["minimal" "systemd-policy" "shell" "dev" "ai" "browser" "media" "desktop"];
    modules = [../hosts/poseidon/configuration.nix];
  };

  mtfuji = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "containers"];
    modules = [../hosts/mtfuji/configuration.nix];
    # The container floor, named leaf by leaf: base toolbox + shell + the
    # skills materialization (the only unconditional piece of user.ai).
    # roles.minimal's user.ai wrapper is skipped, so profiles.ai has no
    # surface to disable.
    hmModules = ["user.base" "shell" "user.ai.skills"];
  };

  kellerbench = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "containers"];
    modules = [../hosts/kellerbench/configuration.nix];
    # The container floor, named leaf by leaf: base toolbox + shell + the
    # skills materialization (the only unconditional piece of user.ai).
    # roles.minimal's user.ai wrapper is skipped, so profiles.ai has no
    # surface to disable.
    hmModules = ["user.base" "shell" "user.ai.skills"];
  };

  deckstation = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "containers"];
    modules = [../hosts/deckstation/configuration.nix];
    # The container floor, named leaf by leaf: base toolbox + shell + the
    # skills materialization (the only unconditional piece of user.ai).
    # roles.minimal's user.ai wrapper is skipped, so profiles.ai has no
    # surface to disable.
    hmModules = ["user.base" "shell" "user.ai.skills"];
  };

  delphi = {
    kind = "nixos";
    system = "aarch64-linux";
    features = ["base" "containers" "disko"];
    modules = [
      ../hosts/delphi/configuration.nix
      # microvm retired on delphi (OCI A1 lacks KVM hardware acceleration;
      # Stirling PDF now runs natively on Delphi)
      # microvm guest import removed; all services served directly via
      # tailnet mounts above.
      # Install-time layout (disko also owns delphi's fileSystems). OCI
      # paravirtualized boot volumes enumerate as /dev/sda; verify with
      # `lsblk` on the instance BEFORE the first nixos-anywhere run — disko
      # wipes the device it is given.
      (import ../hosts/delphi/disko.nix {device = "/dev/sda";})
    ];
    # The container floor, named leaf by leaf: base toolbox + shell + the
    # skills materialization (the only unconditional piece of user.ai).
    # roles.minimal's user.ai wrapper is skipped, so profiles.ai has no
    # surface to disable.
    hmModules = ["user.base" "shell" "user.ai.skills"];
  };
  eisen = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "nixos" "dms"];
    hmFeatures = ["minimal" "systemd-policy" "shell" "dev" "ai" "browser" "media" "desktop"];
    modules = [../hosts/eisen/configuration.nix];
  };

  applevalley = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "containers"];
    modules = [
      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t420
      ../hosts/applevalley/configuration.nix
    ];
    # The container floor, named leaf by leaf: base toolbox + shell + the
    # skills materialization (the only unconditional piece of user.ai).
    # roles.minimal's user.ai wrapper is skipped, so profiles.ai has no
    # surface to disable.
    hmModules = ["user.base" "shell" "user.ai.skills"];
  };

  frieren = {
    kind = "nixos";
    system = "x86_64-linux";
    # No `microvm.vms.*` here: the guest this host runs is the out-of-band canary
    # runner (`microvmRunners.frieren-canary`, started by scripts/task/run-canary.sh),
    # not a declared VM. The `sandbox` guest that used to be imported here belongs
    # to delphi — importing it declared dead `microvm@sandbox` units, an `Host
    # sandbox` ssh alias and a `/var/lib/microvms/sandbox` state dir on the NAS that
    # nothing started. The bridge and NAT the canary needs come from
    # modules/profiles/microvm-host.nix, which infra-stack.nix imports directly.
    features = ["base" "nixos" "dms"];
    hmFeatures = ["minimal" "systemd-policy" "shell" "dev" "ai" "browser" "media" "desktop"];
    modules = [../hosts/frieren/configuration.nix];
  };

  ares = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "containers" "impermanence"];
    modules = [
      ../hosts/ares/configuration.nix
      (import ../hosts/common/disko.nix {device = "/dev/sda";})
    ];
    # The container floor, named leaf by leaf: base toolbox + shell + the
    # skills materialization (the only unconditional piece of user.ai).
    # roles.minimal's user.ai wrapper is skipped, so profiles.ai has no
    # surface to disable.
    hmModules = ["user.base" "shell" "user.ai.skills"];
  };

  stark = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "nixos" "dms" "disko"];
    hmFeatures = ["minimal" "systemd-policy" "shell" "dev" "ai" "browser" "media" "desktop"];
    modules = [
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
    # Back on dwl (2026-11-09). The Ryoku pilot ran 2026-10-31 → 2026-11-09 and is
    # over: on this 15 W Picasso APU the Ryoku session with the DisplayLink manager
    # daemon was intolerable in daily use. The desktop is a fork, not a disable
    # [[flake/policies.nix#desktop-fork-not-disable]]: globalModulesNixos is the
    # fleet chain and the session comes from profiles.dwl-desktop, the same profile
    # netbook and scratch adopt.
    features = ["base" "nixos" "dms" "disko"];
    hmFeatures = ["minimal" "systemd-policy" "shell" "dev" "ai" "browser" "media"];
    modules = [
      ../hosts/fern/configuration.nix
      (import ../hosts/fern/disko.nix {device = "/dev/nvme0n1";})
    ];
  };

  schneeeule = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "nixos" "dms" "impermanence"];
    hmFeatures = ["minimal" "systemd-policy" "shell" "dev" "ai" "browser" "media" "desktop"];
    modules = [
      ../hosts/schneeeule/configuration.nix
      (import ../hosts/common/disko.nix {device = "/dev/sda";})
    ];
  };

  scratch = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "nixos" "dms"];
    hmFeatures = ["minimal" "systemd-policy" "shell" "dev" "ai" "browser" "media" "desktop"];
    modules = [../hosts/scratch/configuration.nix];
  };

  aristotle = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "nixos" "dms"];
    hmFeatures = ["minimal" "systemd-policy" "shell" "dev" "ai" "browser" "media" "desktop"];
    modules = [../hosts/aristotle/configuration.nix];
  };

  diogenes = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "nixos" "dms"];
    hmFeatures = ["minimal" "systemd-policy" "shell" "dev" "ai" "browser" "media" "desktop"];
    modules = [../hosts/diogenes/configuration.nix];
  };

  # netbook carries no global module chain — its own configuration is the whole
  # system — and it follows the fleet's nixpkgs like every other host. What it
  # pins instead is the KERNEL: `boot.kernelPackages = pkgs.linuxPackages` (LTS)
  # in hosts/netbook/configuration.nix, because the newest kernel's initrd could
  # not mount this eMMC box's root. The pinned nixpkgs returned when upstream
  # removed scripted initrd outright — a channel island, but the only rev where
  # this box's stage-1 exists (see the `nixpkgs-netbook` input comment).
  netbook = {
    kind = "nixos";
    system = "x86_64-linux";
    # Scripted initrd is gone upstream; this pin keeps the eMMC-bootable
    # variant (see the input's comment in flake.nix).
    nixpkgs = inputs.nixpkgs-netbook;
    # Its own configuration is the whole system, so it takes the compiled-inventory
    # injection explicitly — the same reason the microVM hosts below do. Without it
    # the host has no `config.fleet.inventory`, which `checks.<system>.inventory-modules`
    # rejects structurally and `hostChecks` rejects when it reads the registry.
    features = ["inventory"];
    modules = [../hosts/netbook/configuration.nix];
  };

  aceofspades = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "nixos" "dms"];
    hmFeatures = ["minimal" "systemd-policy" "shell" "dev" "ai" "browser" "media" "desktop"];
    modules = [../hosts/aceofspades/configuration.nix];
  };

  ancientace = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "nixos" "dms"];
    hmFeatures = ["minimal" "systemd-policy" "shell" "dev" "ai" "browser" "media" "desktop"];
    modules = [../hosts/ancientace/configuration.nix];
  };

  guckloch = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "containers"];
    modules = [
      ../hosts/guckloch/configuration.nix
      inputs.nixos-wsl.nixosModules.default
    ];
    # The container floor, named leaf by leaf: base toolbox + shell + the
    # skills materialization (the only unconditional piece of user.ai).
    # roles.minimal's user.ai wrapper is skipped, so profiles.ai has no
    # surface to disable.
    hmModules = ["user.base" "shell" "user.ai.skills"];
  };

  minyx = {
    kind = "nixos";
    system = "aarch64-linux";
    # Its own chain, not globalModulesContainers: that one imports noDE.nix,
    # which wires Home Manager — for a host deliberately built without it — and
    # carries the impermanence/disko pair that an sd-image root filesystem
    # makes meaningless. The tunnel role needs native NixOS options only.
    features = ["base"];
    modules = [
      moduleFiles."global.determinate-nix"
      inputs.sops-nix.nixosModules.sops
      ../hosts/minyx/configuration.nix
      inputs.nixos-hardware.nixosModules.raspberry-pi-3
    ];
  };

  sledgehammer = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "containers" "disko"];
    modules = [../hosts/sledgehammer/configuration.nix];
    # The container floor, named leaf by leaf: base toolbox + shell + the
    # skills materialization (the only unconditional piece of user.ai).
    # roles.minimal's user.ai wrapper is skipped, so profiles.ai has no
    # surface to disable.
    hmModules = ["user.base" "shell" "user.ai.skills"];
  };

  demo = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["base" "demo"];
    modules = [../hosts/demo/configuration.nix];
    hmModules = ["roles.demo"];
  };

  testvm = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["inventory"];
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

  frieren-canary = {
    kind = "nixos";
    system = "x86_64-linux";
    features = ["inventory"];
    modules = [
      inputs.microvm.nixosModules.microvm
      ../hosts/microvms/frieren-canary.nix
    ];
  };

  penguin = {
    kind = "home";
    system = "x86_64-linux";
    extraSpecialArgs = {inherit inputs self;};
    features = ["home"];
    modules = [../hosts/penguin.nix];
    hmModules = ["shell" "env" "lf" "sops" "scripts"];
  };

  alarm = {
    kind = "home";
    system = "aarch64-linux";
    extraSpecialArgs = {inherit inputs self;};
    features = ["home"];
    modules = [../hosts/alarm.nix];
    hmModules = ["roles.minimal"];
  };

  kali = {
    kind = "home";
    system = "aarch64-linux";
    extraSpecialArgs = {inherit inputs self;};
    features = ["home"];
    modules = [../hosts/kali.nix];
    hmModules = ["shell.starship" "roles.minimal"];
  };

  # The Instabox VM. `kind = "home"` is the honest projection: we own only the
  # user profile there, not a system. It joins `globalModulesHome` so a profile
  # edit and a fleet host are one code path, and `hosts/clanker.nix` re-points
  # `home.username` at Instabox's own account.
  clanker = {
    kind = "home";
    system = "x86_64-linux";
    extraSpecialArgs = {inherit inputs self;};
    features = ["home"];
    modules = [../hosts/clanker.nix];
    hmModules = ["roles.lean"];
  };

  cassini = {
    kind = "darwin";
    system = "aarch64-darwin";
    features = ["base" "macos"];
    # darwin has no systemd: the `systemd-policy` feature reads
    # `osConfig.systemd.services`, which is not an option there.
    hmFeatures = ["minimal" "shell" "dev" "ai" "browser" "media" "desktop"];
    modules = [../hosts/cassini/configuration.nix];
  };
}
