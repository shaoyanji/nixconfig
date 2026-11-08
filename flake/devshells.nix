# The per-system dev shells, as the body of flake-parts' `perSystem`; the shells
# are registry addresses (`.#modules."config.shells.flaskpy"`), and `root` is the
# source path `scripts/openwrt/openwrt.sh` reads.
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
