# The shared AppImage library as a menu: fuzzel where it exists, wmenu on the
# low-end profiles. Nothing is preloaded — see #library-content-is-not-scheduled.
{
  self,
  lib,
  pkgs,
  ...
}: let
  menu = import self.modules."scripts.appimage-menu" {inherit pkgs;};
in
  lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    home.packages = [menu];
  }
