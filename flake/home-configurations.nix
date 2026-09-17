{
  projectHosts,
  inputs,
  nixpkgs,
}:
projectHosts "home" (_: host:
inputs.home-manager.lib.homeManagerConfiguration {
  extraSpecialArgs = host.extraSpecialArgs or {};
  # Standalone HM hosts build their own pkgs; apply the repo overlays so
  # kickstart-nixvim's treesitter config resolves the tmux grammar that
  # nvim-treesitter dropped upstream.
  pkgs = (nixpkgs.legacyPackages.${host.system}).extend (
    import ../overlays/nvim-treesitter-tmux.nix
  );
  inherit (host) modules;
})
