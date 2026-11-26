# Canonical home-manager baseline for embedded (NixOS/darwin) configs.
{
  self,
  inputs,
  lib,
  config,
  user,
  hostInventory,
  ...
}: let
  hmShared = import self.nixFiles.lib."hm-shared.nix" {inherit self inputs;};
  # The host's own role list, declared next to its `features`/`modules` in
  # flake/host-inventory.nix. A host without the field takes the full set —
  # the same value it had before the list became data. nix-darwin leaves
  # `networking.hostName` null (it is an option, so `or` does not fire), and
  # standalone chains have no `networking` at all — either way the shared
  # default degrades rather than erroring the eval.
  hostName = config.networking.hostName or "";
  # One predicate behind all three fields (lib/hm-shared.nix): the host's own
  # value when its inventory entry names it, the shared default when it does not.
  hostField = hmShared.forHost hostInventory hostName;
  hostFeatures = hostField "hmFeatures" user.hmFeatures;
  hostBase = hostField "hmBase" user.hmBaseFeatures;
  hostAi = hostField "hmAi" user.hmAiFeatures;
in {
  # A second Wayland shell cannot share a session with DMS: whichever starts
  # last owns the bar, lock and notification surfaces. A host that owns its own
  # shell turns this off, which also drops `user/desktop/niri.nix` (see
  # roles/home.nix) — the `imports` fork is an option here, never an mkForce.
  options.fleet.dankShell.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Import the DMS shell and niri home modules into embedded HM.";
  };

  # `imports` is a module argument, so a fork has to be an option, not mkForce.
  options.fleet.hmUserModules = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [self.modules."roles.home"];
    description = "Home-manager modules for the embedded `devji` user.";
  };

  # Which parts of `roles.home` this host builds. A name the role does not know
  # is a typo, and an enum makes that an eval error instead of a silently
  # ignored string. The default is the host's own `hmFeatures` from
  # flake/host-inventory.nix (mkDefault, so an explicit definition still wins);
  # `modules/global/user.nix` is only the enum and the no-field fallback.
  options.fleet.hmUserFeatures = lib.mkOption {
    type = lib.types.listOf (lib.types.enum user.hmFeatures);
    default = user.hmFeatures;
    description = "Named features of the desktop role (modules/roles/home.nix).";
  };

  # mkDefault (1000): above the option default (1500), below an explicit host
  # definition (100). An edit to one host's role is an edit to its inventory
  # entry — it cannot reach the other eleven.
  # The leaf lists inside `user.base`/`user.ai`: an import decision like
  # hmUserFeatures, so it is an option + a module argument, never a config read.
  options.fleet.hmBaseFeatures = lib.mkOption {
    type = lib.types.listOf (lib.types.enum user.hmBaseFeatures);
    default = user.hmBaseFeatures;
    description = "Named leaf modules of user/base.nix.";
  };
  options.fleet.hmAiFeatures = lib.mkOption {
    type = lib.types.listOf (lib.types.enum user.hmAiFeatures);
    default = user.hmAiFeatures;
    description = "Named leaf modules of user/ai/default.nix.";
  };

  config.fleet.hmUserFeatures = lib.mkDefault hostFeatures;
  config.fleet.hmBaseFeatures = lib.mkDefault hostBase;
  config.fleet.hmAiFeatures = lib.mkDefault hostAi;

  config.home-manager =
    hmShared.baseline
    // {
      # `self` gives home modules the flake's compiled artifacts (homeAgents,
      # agentSkills, …) without re-reading the repo at activation time. The
      # passthrough of the fleet options is an extraSpecialArgs, not a config
      # read: an import decision, taken before `config` exists inside the HM
      # module system — resolving it through `_module.args` forces `config`
      # inside `imports`, the recursion trap (see `roles/home.nix`). This block
      # used to be spelled identically in global.nixos and global.macos.
      extraSpecialArgs = {
        inherit inputs self;
        fleetHost = config.networking.hostName;
        dankShell = config.fleet.dankShell.enable;
        hmUserFeatures = config.fleet.hmUserFeatures;
        hmBaseFeatures = config.fleet.hmBaseFeatures;
        hmAiFeatures = config.fleet.hmAiFeatures;
      };
      users.${user.name}.imports = config.fleet.hmUserModules;
      sharedModules =
        [
          # The constants module takes `user` as an argument; HM is a nested eval, so
          # the value is injected there too (the file says why).
          hmShared.hmUser
          hmShared.sops
          hmShared.nixvim
          hmShared.nixIndex
          # Per-host ~/AGENTS.md from `.#homeAgents.<host>` (lib/home-agents.nix).
          # Shared by every embedded NixOS/darwin HM config; needs self + fleetHost
          # in that host's extraSpecialArgs (modules/global/{nixos,macos}.nix).
          hmShared.homeAgents
          hmShared.taskShim
        ]
        ++ lib.optionals config.fleet.dankShell.enable hmShared.dankShell;
    };
}
