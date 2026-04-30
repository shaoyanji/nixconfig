# Shell builder function to eliminate duplication across devShells
# Usage:
#   { pkgs }: let
#     builder = import ./builder.nix { inherit pkgs; };
#   in builder.mkDevShell {
#     name = "flaskpy";
#     packages = with pkgs; [ common.python-flask ];
#     greeting = "Hello, Flask!";
#     extraHooks = [ hooks.greeting ];
#   }
{pkgs, lib}: let
  common = pkgs.callPackage ./common-packages.nix {};
  hooks = pkgs.callPackage ./shell-hooks.nix {};
in {
  # Create a standardized development shell
  mkDevShell = {
    name,
    packages,
    greeting ? "Hello, Nix!",
    extraHooks ? [],
  }:
    pkgs.mkShell {
      packages = packages;
      GREETING = greeting;
      shellHook = ''
        ${lib.concatStringsSep "\n" extraHooks}
      '';
    };

  # Convenience functions for common shell patterns
  mkCoreShell = extraPackages:
    mkDevShell {
      name = "core";
      packages = with pkgs; [common.core common.greeting] ++ extraPackages;
      extraHooks = [hooks.full hooks.greeting];
    };

  mkMinimalShell = packages:
    mkDevShell {
      name = "minimal";
      packages = with pkgs; [common.greeting] ++ packages;
      extraHooks = [hooks.greeting];
    };

  mkPackageShell = {name, package, greeting ? "Hello, Nix!"}:
    mkDevShell {
      inherit name greeting;
      packages = with pkgs; [common.greeting package];
      extraHooks = [hooks.greeting];
    };
}