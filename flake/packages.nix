{
  lib,
  systems,
  pkgsFor,
}:
  lib.genAttrs systems.default (
    system: let
      pkgs = pkgsFor system;
    in {
      backend = pkgs.callPackage ../pkgs/go-backend.nix {};
      nullclaw = pkgs.callPackage ../pkgs/nullclaw.nix {};
    }
  )
