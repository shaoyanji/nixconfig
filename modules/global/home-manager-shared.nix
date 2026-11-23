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
  # The host's own role list, declared next to its `features`/`modules` in
  # flake/host-inventory.nix. A host without the field takes the full set —
  # the same value it had before the list became data. nix-darwin leaves
  # `networking.hostName` null (it is an option, so `or` does not fire), and
  # standalone chains have no `networking` at all — either way the shared
  # default degrades rather than erroring the eval.
  hostName = config.networking.hostName or "";
  hostFeatures =
    if builtins.isString hostName && builtins.hasAttr hostName hostInventory
    then hostInventory.${hostName}.hmFeatures or user.hmFeatures
    else user.hmFeatures;
  hostBase =
    if builtins.isString hostName && builtins.hasAttr hostName hostInventory
    then hostInventory.${hostName}.hmBase or user.hmBaseFeatures
    else user.hmBaseFeatures;
  hostAi =
    if builtins.isString hostName && builtins.hasAttr hostName hostInventory
    then hostInventory.${hostName}.hmAi or user.hmAiFeatures
    else user.hmAiFeatures;
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

  config.home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    users.${user.name}.imports = config.fleet.hmUserModules;
    sharedModules =
      [
        # The constants module takes `user` as an argument; HM is a nested eval, so
        # the value is injected there too (the file says why).
        self.modules."global.hm-user"
        inputs.sops-nix.homeManagerModules.sops
        inputs.kickstart-nixvim.homeManagerModules.default
        inputs.nix-index-database.homeModules.nix-index
        # Per-host ~/AGENTS.md from `.#homeAgents.<host>` (lib/home-agents.nix).
        # Shared by every embedded NixOS/darwin HM config; needs self + fleetHost
        # in that host's extraSpecialArgs (modules/global/{nixos,macos}.nix).
        self.modules."user.ai.home-agents"
        self.modules."user.task-shim"
      ]
      ++ lib.optionals config.fleet.dankShell.enable [
        inputs.niri.homeModules.niri
        inputs.dms.homeModules.dank-material-shell
        inputs.dms.homeModules.niri
      ];
  };
}
