{ config, pkgs, inputs, ... }:
let
  local_ssh_key= "local/mb1/ssh/private-key";
  #local_ssh_key= "local/ps1xp/ssh/private-key";
  ssh_key_path = "${config.home.homeDirectory}/.ssh/id_ed25519";
  age_key_path = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  taskfile_path = ./secrets/Taskfile.yaml;
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];
  
  sops = {
    age = {
      keyFile = "${age_key_path}";
      generateKey = true;
      # sshKeyPaths = [ "${ssh_key_path}" ];
    };
    defaultSopsFile = ./secrets/secrets.yaml;
    validateSopsFiles=false;
    secrets."${local_ssh_key}".path = "${ssh_key_path}";
  };
  home.sessionVariables = {
  };
  home.packages = with pkgs; [
    #cifs-utils
    sops
    #   yq
    yq-go
    #    pass
    #    gnupg
    #    age

    (pkgs.writeShellScriptBin "loginssh" ''
      sudo ssh $(${pkgs.sops}/bin/sops -d --extract '["server"]["commands"]' ${config.sops.defaultSopsFile} | ${pkgs.gum}/bin/gum choose) 
    '')
    (pkgs.writeShellApplication {
      name = "load-taskfile";
      runtimeInputs = [ pkgs.sops ];
      text = ''
        ${pkgs.sops}/bin/sops -d ${taskfile_path} > ./Taskfile.yml
      '';
    })
      
  ];
  
  home.file={
    
  };

}
