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
          pkgs.nodejs
          pkgs.go
          pkgs.gopls
        ];
      };
    }
  )
