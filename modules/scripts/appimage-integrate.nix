# appimage-integrate — XDG launchers for the AppImages in the shared library.
# Body and rationale: [`appimage-integrate.sh`](../../scripts/task/appimage-integrate.sh).
# Packaged here rather than inline in the home-manager module because the netbook
# runs alice without home-manager, and the same binary serves both.
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "appimage-integrate";
  runtimeInputs = with pkgs; [
    binutils
    coreutils
    file
    gawk
    gnugrep
    gnused
    squashfs-tools
  ];
  text = builtins.readFile ../../scripts/task/appimage-integrate.sh;
}
