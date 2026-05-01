{nixpkgs}: let
  overlays = [
    # nvidia-persistenced-fix.nix removed - persistenced disabled on all hosts
    (final: prev: {
      linuxPackages = prev.linuxPackages // {
        nvidia_x11 = prev.linuxPackages.nvidia_x11.overrideAttrs (old: {
          makeFlags = old.makeFlags or [];
        });
      };
    })
  ];
in
  system: import nixpkgs {inherit system overlays;}
