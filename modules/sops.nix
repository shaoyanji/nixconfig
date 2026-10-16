{
  config,
  lib,
  pkgs,
  osConfig ? null,
  ...
}: let
  # Hosts with initialized and registered TPM 2.0 identities
  # (frieren is active; add "fern" once fern's tpm-identity.txt is generated & registered)
  tpmHosts = ["frieren"];
  useTpm = (osConfig != null && builtins.elem (osConfig.networking.hostName or "") tpmHosts);
  tpm_key_path = "${config.home.homeDirectory}/.config/sops/age/tpm-identity.txt";
  default_key_path = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
in {
  imports = [];

  sops = {
    age = {
      keyFile = lib.mkDefault (
        if useTpm
        then tpm_key_path
        else default_key_path
      );
      generateKey = lib.mkDefault (!useTpm);
      #sshKeyPaths = [ "${ssh_key_path}" ];
    };
    # defaultSopsFile = "${inputs.secrets."secrets.yaml"}";
    defaultSopsFile = ./secrets.yaml;
    validateSopsFiles = false;
    secrets = {
      "cfcertpem".path = "${config.home.homeDirectory}/.cloudflared/cert.pem";
      "cloak".path = "${config.home.homeDirectory}/.cloak/accounts";
      "ghsudo" = {};
      "gmail" = {};
      "aws/access/key/id" = {};
      "aws/secret/access/key" = {};
      "openmeteo/api/key" = {};
      "neocities" = {};
      "gemini/api/key" = {};
      # "todoist" = {
      #   sopsFile = ./secrets.json;
      #   mode = "0600";
      #   key = "";
      #   format = "json";
      # };
      #"${local_ssh_key}".path = "${ssh_key_path}";
      "ssh_user_ca_private_key" = {
        sopsFile = ./ssh-ca-key.yaml;
        path = "${config.home.homeDirectory}/.ssh/user_ca_key";
        mode = "0600";
      };
    };
    templates = {
      "geminicommit".content = ''
        [api]
        baseurl = ""
        key = '${config.sops.placeholder."gemini/api/key"}'
        model = "gemini-2.5-flash"

        [behavior]
        auto_select = false
        dry_run = false
        no_confirm = false
        no_verify = false
        push = false
        quiet = false
        show_diff = false
        stage_all = false

        [commit]
        language = "english"
        max_length = 72
      '';
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
    "geminicommit/config.toml".source = config.lib.file.mkOutOfStoreSymlink "${config.sops.templates."geminicommit".path}";
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
    ] ++ lib.optional useTpm pkgs.age-plugin-tpm;
    file = {
      ".aws/credentials".source = config.lib.file.mkOutOfStoreSymlink "${config.sops.templates."awscredentials".path}";
    };
  };
}
