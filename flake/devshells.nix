{
  lib,
  systems,
  pkgsFor,
}:
  lib.genAttrs systems.default (
    system: let
      pkgs = pkgsFor system;
    in {
      default = pkgs.mkShell {
        nativeBuildInputs = [
          pkgs.age
          pkgs.bat
          pkgs.direnv
          pkgs.eza
          pkgs.fd
          pkgs.git
          pkgs.nodejs
          pkgs.go
          pkgs.gopls
          pkgs.go-task
          pkgs.gum
          pkgs.jq
          pkgs.ripgrep
          pkgs.sops
          pkgs.yq-go
        ];
      };
    }
  )
