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
  nixvim = inputs.kickstart-nixvim.homeManagerModules.default;
  nixIndex = inputs.nix-index-database.homeModules.nix-index;
  homeAgents = self.modules."user.ai.home-agents";
  taskShim = self.modules."user.task-shim";
  dankShell = [
    inputs.niri.homeModules.niri
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
  ];
}
