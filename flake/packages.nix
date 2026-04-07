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
    xsMaterializerPkg = pkgs.callPackage ../pkgs/xs-materializer.nix {};
  in {
    nullclaw = pkgs.callPackage ../pkgs/nullclaw.nix {};
    openfang = pkgs.callPackage ../pkgs/openfang.nix {};
    qwen-code = pkgs.callPackage ../pkgs/qwen-code.nix {};
    xs = xsPkg;
    xs-materializer = xsMaterializerPkg;
    xs-helper = pkgs.callPackage ../pkgs/xs-helper.nix {
      xs = xsPkg;
      xs-materializer = xsMaterializerPkg;
    };
  }
)
