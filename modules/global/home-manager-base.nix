{
  inputs,
  ...
}: {
  # Canonical home-manager sharedModules baseline.
  # Per-OS modules (nixos.nix, macos.nix, noDE.nix, impermanence.nix)
  # import this and only add role-specific users.devji.imports and extraSpecialArgs.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    sharedModules = [
      inputs.sops-nix.homeManagerModules.sops
      inputs.kickstart-nixvim.homeManagerModules.default
      inputs.nix-index-database.homeModules.nix-index
      inputs.dms.homeModules.dank-material-shell
      inputs.dms.homeModules.niri
    ];
    extraSpecialArgs = {inherit inputs;};
  };
}
