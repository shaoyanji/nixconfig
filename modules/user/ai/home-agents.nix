# ~/AGENTS.md — one link, every home.
#
# The content is produced by the flake (`.#homeAgents.<host>`, lib/home-agents.nix):
# fleet preamble + compiled inventory card + persona. This module only links it.
#
# `fleetHost` and `self` come from extraSpecialArgs:
#   * NixOS   — modules/global/nixos.nix         (fleetHost = config.networking.hostName)
#   * darwin  — modules/global/macos.nix         (same)
#   * demo    — modules/global/demo.nix          (same)
#   * containers — modules/global/noDE.nix       (same)
#   * standalone HM — flake/home-configurations.nix (fleetHost = projection name)
#
# `force` is deliberate: hosts that still carry the old Python-generated regular
# file are converted to the store symlink on the next switch. Home Manager's
# backupFileExtension keeps the previous copy as AGENTS.md.hm-backup on NixOS.
{
  lib,
  self,
  fleetHost ? null,
  ...
}: {
  home.file."AGENTS.md" = lib.mkIf (fleetHost != null) {
    source = self.homeAgents.${fleetHost};
    force = true;
  };
}
