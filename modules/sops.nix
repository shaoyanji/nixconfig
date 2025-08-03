{
  config,
  pkgs,
  inputs,
  ...
}: let
  age_key_path = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  taskfile_path = ./secrets/Taskfile.yaml;
in {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    # inputs.secrets
  ];

  sops = {
    age = {
      keyFile = "${age_key_path}";
      generateKey = true;
      #sshKeyPaths = [ "${ssh_key_path}" ];
    };
    # defaultSopsFile = "${inputs.secrets."secrets.yaml"}";
    defaultSopsFile = ./secrets.yaml;
    validateSopsFiles = false;
    secrets = {
      "awscredentials".path = "${config.home.homeDirectory}/.aws/credentials";
      "cfcertpem".path = "${config.home.homeDirectory}/.cloudflared/cert.pem";
      "cloak".path = "${config.home.homeDirectory}/.cloak/accounts";
      "ghsudo" = {};
      #"${local_ssh_key}".path = "${ssh_key_path}";
      #
    };
    templates = {
      "hosts.yml".content =
        /*
        yaml
        */
        ''
          github.com:
                users:
                    shaoyanji:
                        oauth_token: ${config.sops.placeholder.ghsudo}
                git_protocol: ssh
                oauth_token: ${config.sops.placeholder.ghsudo}
                user: shaoyanji
        '';
      "nix.conf".content = ''
        access-tokens = github.com=${config.sops.placeholder.ghsudo}
      '';
    };
  };
  xdg.configFile."gh/hosts.yml".source = config.lib.file.mkOutOfStoreSymlink "${config.sops.templates."hosts.yml".path}";
  xdg.configFile."nix/nix.conf".source = config.lib.file.mkOutOfStoreSymlink "${config.sops.templates."nix.conf".path}";
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
