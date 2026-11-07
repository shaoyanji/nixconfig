{
  description = "Turns read-path prototypes: Go, Rust and Elixir on one bench";

  # The box has no cache key of its own; every toolchain here is a substitution.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = {nixpkgs, ...}: let
    forAll = f: nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"] (system: f nixpkgs.legacyPackages.${system});
  in {
    devShells = forAll (pkgs: {
      default = pkgs.mkShell {
        packages = [
          pkgs.go
          pkgs.rustc
          pkgs.cargo
          # rustc shells out to `cc` to link; without it every crate's build
          # script dies at the first rlib (measured 2026-11-07).
          pkgs.stdenv.cc
          pkgs.elixir_1_18
          pkgs.erlang
          pkgs.python3
          pkgs.curl
          pkgs.jq
          pkgs.git
        ];
        shellHook = ''
          echo "turns-runtime: $(go version | cut -d' ' -f3) · $(rustc --version) · $(elixir --version | tail -1)"
        '';
      };
    });
  };
}
