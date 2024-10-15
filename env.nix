{ config, pkgs, inputs,... }:

{
  # imports = [ inputs.sops-nix.nixosModules.sops ];
  programs.git = {
    enable=true;
    userName="shaoyanji";
    userEmail="matt@bountystash.com";
  };

  home.sessionVariables = {
  };
  home.packages = with pkgs; [
        sops
    #    pass
    #    gnupg
    #    age
    (pkgs.writeShellScriptBin "secrets" ''
      ${pkgs.sops}/bin/sops -d ~/secrets/api.env
    '')

  ];
  home.file={
    "secrets/api.env" = {
  	source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix-darwin/secrets/api.env";
    };
    # Macbook
    "Library/Application Support/sops/age/keys.txt" = {
  	source = config.lib.file.mkOutOfStoreSymlink "/Volumes/FRITZ.NAS/External-USB3-0-01/documents/age-key.txt";
    };
    # Linux
    ".config/sops/age/keys.txt" = {
        source = config.lib.file.mkOutOfStoreSymlink "/mnt/y/documents/age-key.txt";
    };
  };

}
