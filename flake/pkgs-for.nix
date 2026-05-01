{nixpkgs}: let
  overlays = [
    (import ../overlays/nvidia-persistenced-fix.nix)
  ];
in
  system: import nixpkgs {inherit system overlays;}
