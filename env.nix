{ config, pkgs, inputs, ... }:
let

  #  key_path ='' \$\{pkgs\.sops\}/bin/sops -d --extract '\["keyrepo"\]\["mac"\]' \./secrets/secrets\.yaml'';
  ############  key_path = ''${pkgs.sops}/bin/sops -d --extract ./secrets/secrets.yaml '';
  #  key_path ='' ${pkgs.sops}/bin/sops -d --extract "'"["keyrepo"]["mac"]"'" ./secrets/secrets.yaml'';
in
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
    (pkgs.writeShellScriptBin "printidpath" ''
      echo "$(sops -d --extract '["keyrepo"]["mac"]' ~/secrets/secrets.yaml)""$(sops -d --extract '["dragoncourtwhm"]["path"]' ~/secrets/secrets.yaml)"
    '')
    (pkgs.writeShellScriptBin "printport" ''
      echo "$(sops -d --extract '["dragoncourtwhm"]["port"]' ~/secrets/secrets.yaml)"
    '')
    (pkgs.writeShellScriptBin "printuid" ''
      echo "$(sops -d --extract '["dragoncourtwhm"]["user"]' ~/secrets/secrets.yaml)"
    '')
    (pkgs.writeShellScriptBin "printaddress" ''
      echo "$(sops -d --extract '["dragoncourtwhm"]["address"]' ~/secrets/secrets.yaml)"
    '')

    (pkgs.writeShellScriptBin "sftpwhm" ''
       sftp -i $(printidpath) -oPort=$(printport) $(printuid)@$(printaddress)
    '')
  ];
  home.file={
    "secrets/load.env".source = ./secrets/load.env;
    "secrets/secrets.yaml".source = ./secrets/secrets.yaml;
 };

}
