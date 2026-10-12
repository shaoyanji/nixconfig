{
  lib,
  systems,
  pkgsFor,
  ...
}:
lib.genAttrs systems.default (system: let
  pkgs = pkgsFor system;
in {
  simplex-chat = pkgs.simplex-chat;
  smp-server = pkgs.smp-server;
  fleet-docs-site = import ../lib/aki-site.nix {inherit pkgs lib;};
})
