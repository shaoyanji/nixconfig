{nixpkgs}: let
  overlays = [
    (import ../overlays/nvidia-persistenced-fix.nix)
    (import ../overlays/nushell-plugins-compat.nix)
  ];
in
  system: import nixpkgs {inherit system overlays;}
