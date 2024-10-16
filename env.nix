{ config, pkgs, inputs,... }:
{
  #  imports = [ inputs.sops-nix.homeManagerModules.sops ];
  programs.git = {
    enable=true;
    userName="shaoyanji";
    userEmail="matt@bountystash.com";
  };
  sops = {
    age.sshKeyPaths = [ "/home/devji/.ssh/id_ed25519" ];
    defaultSopsFile = ./.sops.yaml;
  };
  home.sessionVariables = {
  };
  home.packages = with pkgs; [
        sops
    #    pass
    #    gnupg
    #    age
     (pkgs.writeShellScriptBin "secrets" ''
     ${pkgs.sops}/bin/sops -d ~/secrets/load.env
    '')
  ];
  home.file={
    "secrets/load.env" = {
    	source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nix-darwin/secrets/load.env";
    };
 };

}
