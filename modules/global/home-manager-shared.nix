# Canonical home-manager sharedModules baseline for embedded (NixOS) configs.
# Import this module instead of repeating sharedModules in every global/*.nix file.
{
  inputs,
  ...
}: {
  home-manager.sharedModules = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.kickstart-nixvim.homeManagerModules.default
    inputs.nix-index-database.homeModules.nix-index
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
  ];
}
