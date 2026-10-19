{
  projectHosts,
  inputs,
  nixpkgs,
  self,
}:
projectHosts "home" (name: host:
inputs.home-manager.lib.homeManagerConfiguration {
  # `fleetHost` is the attrs key, which is the inventory name — the same key
  # `.#homeAgents` uses, so `~/AGENTS.md` resolves for every standalone host.
  extraSpecialArgs =
    (host.extraSpecialArgs or {})
    // {
      inherit self;
      fleetHost = name;
    };
  # Standalone HM hosts build their own pkgs; apply the repo overlays so
  # kickstart-nixvim's treesitter config resolves the tmux grammar that
  # nvim-treesitter dropped upstream.
  pkgs = nixpkgs.legacyPackages.${host.system}.extend (
    import ../overlays/nvim-treesitter-tmux.nix
  );
  inherit (host) modules;
})
