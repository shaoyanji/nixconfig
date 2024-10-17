{ config, pkgs, inputs, ... }:
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];
  programs.git = {
    enable=true;
    userName="shaoyanji";
    userEmail="matt@bountystash.com";
  };
  sops = {
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
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
    
    (pkgs.writeShellScriptBin "keygroq" ''
      ${pkgs.sops}/bin/sops -d --extract '["GROQ_API_KEY"]' ~/secrets/load.env
    '')
  ];
  home.file={
    "secrets/load.env" = {
    	source = ./secrets/load.env;
    };
 };

}
