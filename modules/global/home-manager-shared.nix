# Canonical home-manager sharedModules baseline for embedded (NixOS) configs.
{inputs, ...}: {
  home-manager.sharedModules = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.kickstart-nixvim.homeManagerModules.default
    inputs.nix-index-database.homeModules.nix-index
    inputs.niri.homeModules.niri
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
    # Per-host ~/AGENTS.md from `.#homeAgents.<host>` (lib/home-agents.nix).
    # Shared by every embedded NixOS/darwin HM config; needs self + fleetHost
    # in that host's extraSpecialArgs (modules/global/{nixos,macos}.nix).
    ../user/ai/home-agents.nix
  ];
}
