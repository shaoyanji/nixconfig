# ~/AGENTS.md — one link, every home.
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
