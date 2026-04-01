# PDF tooling and typesetting shell
{pkgs ? import <nixpkgs> {}}:
let
  common = pkgs.callPackage ./common-packages.nix {};
  hooks = pkgs.callPackage ./shell-hooks.nix {};
in
pkgs.mkShell {
  packages = with pkgs; [
    common.greeting
    common.ui
    common.pdf
    common.productivity
    pkgs.viu
    pkgs.nushell
  ];

  GREETING = "Hello, Nix!";
  shellHook = ''
    ${hooks.greeting}
    eval "$(task --completion bash)"
    ${hooks.nushell}
  '';
}
