{ config, pkgs, inputs, ... }:
let
  #local_ssh_key= "local/mb1/ssh/private-key";
  local_ssh_key= "local/ps1xp/ssh/private-key";
  ssh_key_path = "${config.home.homeDirectory}/.ssh/id_ed25519";
  age_key_path = "${config.home.homeDirectory}/.config/age/keys.txt";
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];
  
  sops = {
    age= {
      keyFile = "${age_key_path}";
      generateKey = true;
    };
    #    age.sshKeyPaths = [ "${ssh_key_path}" ];
    defaultSopsFile = ./secrets/secrets.yaml;
    validateSopsFiles=false;
    secrets= {
      ${local_ssh_key} = {
        path= "${ssh_key_path}";
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
      sudo ssh $(${pkgs.sops}/bin/sops -d --extract '["server"]["commands"]' ${config.sops.defaultSopsFile} | ${pkgs.gum}/bin/gum choose) 
    '')
    (pkgs.writeShellScriptBin "mountnwd" ''
      sudo mount.cifs //192.168.178.1/fritz.nas/External-USB3-0-01/ /mnt/y -o rw,noserverino,username=jisifu
      sudo mount.cifs //burgernas/usbshare1 /mnt/z -o rw,noserverino,credentials=/mnt/y/documents/secrets/credentials.txt
      sudo mount.cifs //burgernas/Shared\ Library /mnt/x -o rw,noserverino,credentials=/mnt/y/documents/secrets/credentials.txt
    '')
    (pkgs.writeShellScriptBin "testme" ''
    '')
      
  ];
  
  home.file={
    
  };

}
