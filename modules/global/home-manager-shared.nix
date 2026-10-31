# Canonical home-manager sharedModules baseline for embedded (NixOS) configs.
{
  inputs,
  lib,
  config,
  ...
}: {
  # A second Wayland shell cannot share a session with DMS: whichever starts
  # last owns the bar, lock and notification surfaces. Ryoku hosts turn this
  # off, which also drops `user/desktop/niri.nix` (see roles/home.nix) — the
  # `imports` fork is an option here, never an mkForce.
  options.fleet.dankShell.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Import the DMS shell and niri home modules into embedded HM.";
  };

  config.home-manager.sharedModules =
    [
      inputs.sops-nix.homeManagerModules.sops
      inputs.kickstart-nixvim.homeManagerModules.default
      inputs.nix-index-database.homeModules.nix-index
      # Per-host ~/AGENTS.md from `.#homeAgents.<host>` (lib/home-agents.nix).
      # Shared by every embedded NixOS/darwin HM config; needs self + fleetHost
      # in that host's extraSpecialArgs (modules/global/{nixos,macos}.nix).
      ../user/ai/home-agents.nix
    ]
    ++ lib.optionals config.fleet.dankShell.enable [
      inputs.niri.homeModules.niri
      inputs.dms.homeModules.dank-material-shell
      inputs.dms.homeModules.niri
    ];
}
