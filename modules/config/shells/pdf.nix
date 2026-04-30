# PDF tooling and typesetting shell
{pkgs ? import <nixpkgs> {}}:
let
  builder = pkgs.callPackage ./builder.nix {};
  common = pkgs.callPackage ./common-packages.nix {};
  hooks = pkgs.callPackage ./shell-hooks.nix {};
in
builder.mkDevShell {
  name = "pdf";
  packages = with pkgs; [
    common.greeting
    common.ui
    common.pdf
    common.productivity
    pkgs.viu
    pkgs.nushell
  ];
  greeting = "Hello, Nix!";
  extraHooks = [
    hooks.greeting
    "eval \"$(task --completion bash)\""
    hooks.nushell
  ];
}
