{
  config,
  pkgs,
  inputs,
  ...
}: let
  age_key_path = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  # taskfile_path = ./secrets/Taskfile.yaml;
in {
  imports = [];

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
      "cfcertpem".path = "${config.home.homeDirectory}/.cloudflared/cert.pem";
      "cloak".path = "${config.home.homeDirectory}/.cloak/accounts";
      "ghsudo" = {};
      "aws/access/key/id" = {};
      "aws/secret/access/key" = {};
      "openmeteo/api/key" = {};
      "neocities" = {};
      # "todoist" = {
      #   sopsFile = ./secrets.json;
      #   mode = "0600";
      #   key = "";
      #   format = "json";
      # };
      #"${local_ssh_key}".path = "${ssh_key_path}";
    };
    templates = {
      "stormy.toml".content = ''
        provider = "OpenMeteo"
        api_key = '${config.sops.placeholder."openmeteo/api/key"}'
        city = "Freiburg"
        units = "metric"
        showcityname = false
        use_colors = true
        live_mode = false
        compact = false
      '';
      "awscredentials".content =
        /*
        toml
        */
        ''
          [default]
          aws_access_key_id = ${config.sops.placeholder."aws/access/key/id"}
          aws_secret_access_key = ${config.sops.placeholder."aws/secret/access/key"}
        '';
      # "accounts".content = ''${config.sops.placeholder."cloak2"}'';
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
  xdg.configFile = {
    "gh/hosts.yml".source = config.lib.file.mkOutOfStoreSymlink "${config.sops.templates."hosts.yml".path}";
    "nix/nix.conf".source = config.lib.file.mkOutOfStoreSymlink "${config.sops.templates."nix.conf".path}";
    "stormy/stormy.toml".source = config.lib.file.mkOutOfStoreSymlink "${config.sops.templates."stormy.toml".path}";
    # "todoist/config.json".source = config.lib.file.mkOutOfStoreSymlink "${config.sops.secrets."todoist".path}";
    "neocities/config".source = config.lib.file.mkOutOfStoreSymlink "${config.sops.secrets."neocities".path}";
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
      ".aws/credentials".source = config.lib.file.mkOutOfStoreSymlink "${config.sops.templates."awscredentials".path}";
    };
  };
}
