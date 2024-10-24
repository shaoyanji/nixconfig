{ config, pkgs, inputs, ... }:
let
  ssh_key_path = "${config.home.homeDirectory}/.ssh/id_ed25519";
  sec_yaml_path = ./secrets/secrets.yaml;
  SHELL_DECRYPT = "sec_yaml";
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];
  
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    #age.keyFile = "$(getconf DARWIN_USER_TEMP_DIR)/age_keys.txt";
    #age.sshKeyPaths = [ "${ssh_key_path}" ];
    defaultSopsFile = ./secrets/secrets.yaml;
    validateSopsFiles=false;
      secrets= {
          "local/ps1xp/ssh/private-key"={
          path="%r/secrets.d/ps1xp_ed25519.txt";
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
      ${pkgs.sops}/bin/sops -d --extract '["local"]["mb1"]["ssh"]["private-key"]' ${sec_yaml_path} > "ssh_key_path"
    '')
    (pkgs.writeShellScriptBin "mountnwd" ''
      sudo mount.cifs //192.168.178.1/fritz.nas/External-USB3-0-01/ /mnt/y -o rw,noserverino,username=jisifu
      sudo mount.cifs //burgernas/usbshare1 /mnt/z -o rw,noserverino,credentials=/mnt/y/documents/secrets/credentials.txt
      sudo mount.cifs //burgernas/Shared\ Library /mnt/x -o rw,noserverino,credentials=/mnt/y/documents/secrets/credentials.txt
    '')
    (pkgs.writeShellScriptBin "testme" ''
      ${pkgs.sops}/bin/sops -d --extract '["server"]["keyrepo"]["username"]' ${sec_yaml_path}
    '')
  ];
  
  home.file={
    
  };

}
