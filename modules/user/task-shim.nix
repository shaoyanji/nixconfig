# ~/Taskfile.yml — the $HOME task entry point; AGENTS.nix `taskfile-plane-handmade`.
{
  lib,
  fleetHost ? null,
  ...
}: {
  home.file."Taskfile.yml" = lib.mkIf (fleetHost != null) {
    source = ./task-shim.yml;
    force = true;
  };
}
