{
  config,
  pkgs,
  inputs,
  ...
}: let
  # local_ssh_key= "local/mb1/ssh/private-key";
  # local_ssh_key= "local/ps1xp/ssh/private-key";
  # local_ssh_key= "local/bizmac/ssh/private-key";
  # local_ssh_key= "local/aceofspades/ssh/private-key";
  #ssh_key_path = "${config.home.homeDirectory}/.ssh/id_ed25519";
  age_key_path = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  taskfile_path = ./secrets/Taskfile.yaml;
in {
  imports = [inputs.sops-nix.homeManagerModules.sops];

  sops = {
    age = {
      keyFile = "${age_key_path}";
      generateKey = true;
      #sshKeyPaths = [ "${ssh_key_path}" ];
    };
    defaultSopsFile = ./secrets/secrets.yaml;
    validateSopsFiles = false;
    secrets = {
      "awscredentials".path = "${config.home.homeDirectory}/.aws/credentials";
      "cfcertpem".path = "${config.home.homeDirectory}/.cloudflared/cert.pem";
      "cloak".path = "${config.home.homeDirectory}/.cloak/accounts";
      #"${local_ssh_key}".path = "${ssh_key_path}";
      #
    };
  };
  home = {
    sessionVariables = {
      SOPS_EDITOR = "hx";
    };
    packages = with pkgs; [
      sops
      yq-go
    ];
    file = {
    };
  };
}
