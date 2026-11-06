# The architectures, overlays and package set this flake fans out to, shared by
# `flake.nix` (the flake-parts `systems` option) and `flake/outputs.nix`.
{nixpkgs}: let
  systems = {
    # No darwin entry: the one macOS machine is configuration-only and reachable
    # by name through `darwinConfigurations`; nothing else fans out to it.
    work = ["x86_64-linux" "aarch64-linux"];
    # Both architectures the fleet runs: `checks.<system>` is repo hygiene and
    # forces no host config (budget rule: flake/checks.nix).
    checks = ["x86_64-linux" "aarch64-linux"];
  };

  overlays = [
    (import ../overlays/simplex-chat.nix)
    (import ../overlays/nvidia-persistenced-fix.nix)
    (import ../overlays/nushell-plugins-compat.nix)
    # kickstart.nixvim treesitter.nix still references the tmux grammar
    # that nvim-treesitter dropped upstream
    (import ../overlays/nvim-treesitter-tmux.nix)
    # molly-brown is newer than nixpkgs' 2023 snapshot (upstream has no tags)
    (import ../overlays/molly-brown.nix)
  ];
in {
  inherit systems overlays;

  # A host that pins its own nixpkgs (netbook) gets its own instance through
  # lib/mk-nixos-host.nix; this one is the repo-wide overlay view.
  pkgsFor = system: import nixpkgs {inherit system overlays;};
}
