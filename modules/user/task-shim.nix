# ~/Taskfile.yml — the $HOME task entry point; AGENTS.nix `taskfile-plane-handmade`.
{
  lib,
  fleetHost ? null,
  ...
}: {
  home.file."Taskfile.yml" = lib.mkIf (fleetHost != null) {
    text = ''
      version: "3"
      includes:
          nixconfig:
              taskfile: ~/Documents/nixconfig/Taskfile.yml
              dir: ~/Documents/nixconfig
              flatten: true
    '';
    force = true;
  };
}
