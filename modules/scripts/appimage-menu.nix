# appimage-menu — the library as a menu of names.
# Body: [`appimage-menu.sh`](../../scripts/appimage-menu.sh). Packaged here because
# the netbook runs alice without home-manager and the same binary serves both.
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "appimage-menu";
  runtimeInputs = [pkgs.appimage-run];
  text = builtins.readFile ../../scripts/appimage-menu.sh;
}
