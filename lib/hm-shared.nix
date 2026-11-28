# HM shared-module entries, resolved once — the embedded
# (global.home-manager-shared), container (global.noDE) and demo blocks each
# order their own sharedModules list from these names instead of respelling
# the paths.
{
  self,
  inputs,
}: {
  hmUser = self.modules."global.hm-user";
  sops = inputs.sops-nix.homeManagerModules.sops;
  sopsKeyCoverage = self.modules."global.sops-key-coverage";
  nixvim = inputs.kickstart-nixvim.homeManagerModules.default;
  nixIndex = inputs.nix-index-database.homeModules.nix-index;
  homeAgents = self.modules."user.ai.home-agents";
  taskShim = self.modules."user.task-shim";
  dankShell = [
    inputs.niri.homeModules.niri
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
  ];

  # The embedded-HM baseline knobs every site spells (noDE, demo,
  # home-manager-shared): global pkgs/user packages and the collision suffix.
  baseline = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
  };

  # Name → module path resolution for inventory hmModules lists — the same
  # map in global.noDE, global.demo and global.hm-inventory-role.
  modulePaths = map (m: self.modules.${m});

  # One predicate behind the per-host inventory fields: the host's own value
  # when its inventory entry names it, the fallback when it does not.
  forHost = hostInventory: hostName: field: default:
    if builtins.isString hostName && builtins.hasAttr hostName hostInventory
    then hostInventory.${hostName}.${field} or default
    else default;
}
