# The per-system dev shells, as the body of flake-parts' `perSystem`; the flake
# declares `systems = systems.work`, so this file only names shells. The shells
# are addresses from the module registry (`.#modules."config.shells.flaskpy"`),
# not paths built here: the walk already names them, and a rename that only
# updated this file would otherwise pass the registry gate. `root` is still the
# source path `openwrt` reads (`scripts/openwrt/openwrt.sh`).
{
  pkgs,
  self,
  root ? ../.,
}: {
  default = pkgs.mkShell {
    nativeBuildInputs = [
      pkgs.bashInteractive
      pkgs.nodejs
      pkgs.go
      pkgs.gopls
      # The gate is `checks.<system>.scripts-shellcheck`; this makes the binary
      # reachable to fix what it finds.
      pkgs.shellcheck
    ];
  };

  # Development shells - each file takes pkgs. Spelled out rather than built from
  # a list: the registry records an edge from a literal name, and a name computed
  # in a helper is invisible to `ops:kg:module` and to the dangling scan.
  flaskpy = (import self.modules."config.shells.flaskpy") {inherit pkgs;};
  jekyll = (import self.modules."config.shells.jekyll") {inherit pkgs;};
  yarn = (import self.modules."config.shells.yarn") {inherit pkgs;};
  pdf = (import self.modules."config.shells.pdf") {inherit pkgs;};
  yt = (import self.modules."config.shells.yt") {inherit pkgs;};
  shell = (import self.modules."config.shells.shell") {inherit pkgs;};
  kali = (import self.modules."config.shells.kali") {inherit pkgs;};
  pi = (import self.modules."config.shells.pi") {inherit pkgs;};
  replit = (import self.modules."config.shells.replit") {inherit pkgs;};
  openwrt = (import self.modules."config.shells.openwrt") {
    inherit pkgs;
    root = toString root;
  };
}
