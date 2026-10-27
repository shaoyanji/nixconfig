# fleet-menu — the launcher the dwl session binds. Body and rationale:
# [`fleet-menu.sh`](./fleet-menu.sh).
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "fleet-menu";
  runtimeInputs = with pkgs; [
    bash
    coreutils
    findutils
    gawk
    wmenu
  ];
  text = builtins.readFile ./fleet-menu.sh;
}
