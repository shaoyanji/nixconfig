{
  inputs,
  lib,
  systems,
  pkgsFor,
}:
  lib.genAttrs systems.default (
    system: let
      pkgs = pkgsFor system;
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
    }
  )
