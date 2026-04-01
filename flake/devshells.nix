{
  lib,
  systems,
  pkgsFor,
  self,
}:
  lib.genAttrs systems.default (
    system: let
      pkgs = pkgsFor system;
      # Import shells using the flake's root path
      shellsDir = "${self.outPath}/modules/config/shells";
    in {
      default = pkgs.mkShell {
        nativeBuildInputs = [
          pkgs.nodejs
          pkgs.go
          pkgs.gopls
        ];
      };

      # Development shells - import directly with pkgs
      flaskpy = (import "${shellsDir}/flaskpy.nix") {inherit pkgs;};
      jekyll = (import "${shellsDir}/jekyll.nix") {inherit pkgs;};
      yarn = (import "${shellsDir}/yarn.nix") {inherit pkgs;};
      pdf = (import "${shellsDir}/pdf.nix") {inherit pkgs;};
      yt = (import "${shellsDir}/yt.nix") {inherit pkgs;};
      shell = (import "${shellsDir}/shell.nix") {inherit pkgs;};
      kali = (import "${shellsDir}/kali.nix") {inherit pkgs;};
      pi = (import "${shellsDir}/pi.nix") {inherit pkgs;};
      replit = (import "${shellsDir}/replit.nix") {inherit pkgs;};
    }
  )
