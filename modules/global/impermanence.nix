{
  config,
  pkgs,
  inputs,
  ...
}: {
  # Note: home-manager settings (useGlobalPkgs, sharedModules, etc.) are
  # provided by globalModulesNixos → nixos.nix.  This module only adds
  # impermanence persistence rules for the devji user.
  home-manager.users.devji.home = {
    stateVersion = "25.05";

    persistence."/persist/home" = {
      directories = [
        "Downloads"
        "Music"
        "Pictures"
        "Documents"
        "Videos"
        ".ssh"
        ".supermaven"
        ".local/share/keyrings"
        ".local/share/direnv"
        ".config/direnv"
        ".config/btop"
        ".config/elvish/lib"
        ".config/obsidian"
        ".zen"
        {
          directory = ".local/share/Steam";
        }
      ];
      files = [
        ".config/sops/age/keys.txt"
        "nixconfig"
      ];
    };
  };
}
