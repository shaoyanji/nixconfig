{nixpkgs}: let
  overlays = [
    # nvidia-persistenced-fix.nix removed - persistenced disabled on all hosts
  ];
in
  system: import nixpkgs {inherit system overlays;}
