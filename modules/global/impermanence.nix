{ pkgs, inputs, ... }:

{ 
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];

  home.stateVersion = "24.11"; # Please read the comment before changing.

  home.persistence."/persist/home" = {
    directories = [
      "Downloads"
      "Music"
      "Pictures"
      "Documents"
      "Videos"
      ".ssh"
      ".local/share/keyrings"
      ".local/share/direnv"
      ".supermaven"
      {
        directory = ".local/share/Steam";
        method = "symlink";
      }
    ];
    files = [
      ".config/sops/age/keys.txt"
    ];
    allowOther = true;
  };
}
