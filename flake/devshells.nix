# The per-system dev shells, as the body of flake-parts' `perSystem`; the flake
# declares `systems = systems.work`, so this file only names shells. `root` is the
# source path `openwrt` reads (`scripts/openwrt/openwrt.sh`).
{
  pkgs,
  root ? ../.,
}: let
  shellsDir = root + "/modules/config/shells";
in {
  default = pkgs.mkShell {
    nativeBuildInputs = [
      pkgs.bashInteractive
      pkgs.nodejs
      pkgs.go
      pkgs.gopls
      # tools/kg-engine is Elixir: with it on PATH, `task ops:kg:sidecar` runs
      # offline instead of resolving a store path per invocation.
      pkgs.beamPackages.elixir
      pkgs.beamPackages.erlang
      # The gate is `checks.<system>.scripts-shellcheck`; this makes the binary
      # reachable to fix what it finds.
      pkgs.shellcheck
    ];
  };

  # Development shells - import directly with pkgs
  flaskpy = (import (shellsDir + "/flaskpy.nix")) {inherit pkgs;};
  jekyll = (import (shellsDir + "/jekyll.nix")) {inherit pkgs;};
  yarn = (import (shellsDir + "/yarn.nix")) {inherit pkgs;};
  pdf = (import (shellsDir + "/pdf.nix")) {inherit pkgs;};
  yt = (import (shellsDir + "/yt.nix")) {inherit pkgs;};
  shell = (import (shellsDir + "/shell.nix")) {inherit pkgs;};
  kali = (import (shellsDir + "/kali.nix")) {inherit pkgs;};
  pi = (import (shellsDir + "/pi.nix")) {inherit pkgs;};
  replit = (import (shellsDir + "/replit.nix")) {inherit pkgs;};
  openwrt = (import (shellsDir + "/openwrt.nix")) {
    inherit pkgs;
    root = toString root;
  };
}
