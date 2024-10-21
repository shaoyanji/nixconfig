{ config, pkgs, inputs, ... }:
let
  ssh_key_path = "${config.home.homeDirectory}/.ssh/id_ed25519";
  sec_yaml_path = ./secrets/secrets.yaml;
  SHELL_DECRYPT = "sec_yaml";
  #  key_path ='' \$\{pkgs\.sops\}/bin/sops -d --extract '\["keyrepo"\]\["mac"\]' \./secrets/secrets\.yaml'';
  ############  key_path = ''${pkgs.sops}/bin/sops -d --extract ./secrets/secrets.yaml '';
  #  key_path ='' ${pkgs.sops}/bin/sops -d --extract "'"["keyrepo"]["mac"]"'" ./secrets/secrets.yaml'';
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];
  
  programs.git = {
    enable=true;
    userName="shaoyanji";
    userEmail="jisifu@gmail.com";
    extraConfig = {
      pull.rebase=false;
    };
  };
  sops = {
    #age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    age.keyFile = "$(getconf DARWIN_USER_TEMP_DIR)/age_keys.txt";
    #age.sshKeyPaths = [ "${ssh_key_path}" ];
    defaultSopsFile = ./secrets/secrets.yaml;
    validateSopsFiles=false;
    secrets= {
       "local/mb1/ssh/private-key"={
        #path= "${ssh_key_path}";
        #owner="root";
        #group="wheel";
        #mode="0440";
          path="%r/secrets.d/mb1_ed25519.txt";
        };
    };
  };
  home.sessionVariables = {
  };
  home.packages = with pkgs; [
        sops
    #   yq
        yq-go
    #    pass
    #    gnupg
    #    age

      #(pkgs.writeShellScriptBin "sftpwhm" ''
      #     sftp -oPort=$(printport) $(printuid)@$(printaddress)
      #'')
    (pkgs.writeShellScriptBin "loginssh" ''
      sudo ssh $(${pkgs.sops}/bin/sops -d --extract '["server"]["commands"]' ${sec_yaml_path} | ${pkgs.gum}/bin/gum choose) 
    '')
    (pkgs.writeShellScriptBin "reload_keys" ''
      ${pkgs.sops}/bin/sops -d --extract '["local"]["mb1"]["ssh"]["private-key"]' ${sec_yaml_path} > "$(HOME)/.ssh/id_ed25519"
    '')
      
  ];
  home.file={
 };

}
