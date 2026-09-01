{nixpkgs}: let
  overlays = [
    (import ../overlays/nvidia-persistenced-fix.nix)
    (import ../overlays/nushell-plugins-compat.nix)
    # kickstart.nixvim treesitter.nix still references the tmux grammar
    # that nvim-treesitter dropped upstream
    (import ../overlays/nvim-treesitter-tmux.nix)
  ];
in
  system: import nixpkgs {inherit system overlays;}
