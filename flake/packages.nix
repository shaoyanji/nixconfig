{
  inputs,
  lib,
  systems,
  pkgsFor,
}:
  lib.genAttrs systems.default (
    system: let
      pkgs = pkgsFor system;
      xsPkg = pkgs.callPackage ../pkgs/xs.nix {};
    in {
      backend = pkgs.callPackage ../pkgs/go-backend.nix {};
      hermes-agent = pkgs.callPackage ../pkgs/hermes-agent.nix {
        inherit
          (inputs)
          pyproject-build-systems
          pyproject-nix
          uv2nix
          ;
        src = inputs.hermes-src;
        version = "main";
      };
      nullclaw = pkgs.callPackage ../pkgs/nullclaw.nix {};
      openfang = pkgs.callPackage ../pkgs/openfang.nix {};
      xs = xsPkg;
      xs-helper = pkgs.callPackage ../pkgs/xs-helper.nix {
        xs = xsPkg;
      };
    }
  )
