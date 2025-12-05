{
  config,
  pkgs,
  inputs,
  ...
}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; #for rebuild
    users.devji = {
      imports = [
        ./heim.nix
      ];
      programs.dankMaterialShell = {
        enable = true;
        systemd = {
          enable = true; # Systemd service for auto-start
          restartIfChanged = true; # Auto-restart dms.service when dankMaterialShell changes
        };
        niri = {
          enableKeybinds = true; # Automatic keybinding configuration
          enableSpawn = true; # Auto-start DMS with niri
        };
        default.settings = {
          theme = "dark";
          dynamicTheming = true;
          # Add any other settings here
        };
      };
    };
    sharedModules = [
      inputs.sops-nix.homeManagerModules.sops
      inputs.kickstart-nixvim.homeManagerModules.default
      inputs.nix-index-database.homeModules.nix-index
      # inputs.niri.homeModules.niri
      inputs.dankMaterialShell.homeModules.dankMaterialShell.default
      inputs.dankMaterialShell.homeModules.dankMaterialShell.niri
    ];
    extraSpecialArgs = {inherit inputs;}; # Pass inputs to homeManagerConfiguration
  };
}
