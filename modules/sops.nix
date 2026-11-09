# User-session secrets via sops-nix: the default file, the age identity and each secret's path.
{
  config,
  lib,
  pkgs,
  osConfig ? null,
  ...
}: let
  # A host whose TPM identity is enrolled says so in inventory.toml (`tpm-identity`)
  # instead of being remembered in a list here: the list lived in this file while the
  # enrollment itself lives on the machine, so the two could disagree silently.
  hostName = osConfig.networking.hostName or (config.networking.hostName or "");
  invHost =
    if hostName != ""
    then (osConfig.fleet.inventory.hosts.${hostName} or (config.fleet.inventory.hosts.${hostName} or null))
    else null;
  traits =
    if invHost == null
    then []
    else (invHost.software.traits or []);
  useTpm = osConfig != null && builtins.elem "tpm-identity" traits;
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
      # sops-nix sets the user unit's PATH to *exactly* this list, so a TPM host
      # without it starts the unit with `Environment=PATH=` — the unseal then
      # fails as "0 successful groups" even though the identity is a recipient.
      # home.packages is not enough: the unit does not inherit the login PATH.
      plugins = lib.optional useTpm pkgs.age-plugin-tpm;
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
      # envs.net pubnix mail (mail.envs.net). Same shape as `gmail`: one string,
      # consumed by himalaya's passwordCommand.
      "envsmail" = {};
      # Alwaysdata hosting mailbox (dragoncourt@alwaysdata.net). One string consumed
      # by himalaya's passwordCommand.
      "alwaysdataemail" = {};
      # Cal.com API key for the personal calendar, read by an agent backend that
      # asks for availability and creates a booking through the v2 bookings API.
      # Gated on the `agent-backend` trait rather than declared everywhere: a
      # desktop that never runs an agent has no use for a scheduling credential,
      # and every declared secret is one more file decrypted on that host.
      "caldotcom" = lib.mkIf (builtins.elem "agent-backend" traits) {};
      # Resend's API key, used as the SMTP password for bountystash.com outbound
      # mail (modules/himalaya.nix). The key sits in the apikeys plane, not the
      # default secrets file, so this names both the file and the nested path.
      "resend-api-key" = {
        sopsFile = ./secrets/apikeys.yaml;
        key = "RESEND/API/KEY";
      };
      "aws/access/key/id" = {};
      "aws/secret/access/key" = {};
      # OCI CLI credentials. The private half and the fingerprint that names it
      # travel together: a fingerprint from one keypair against a key file from
      # another authenticates as "NotAuthenticated" with no hint which of the
      # two is wrong, so both are declared here and rendered into one profile.
      "oci/api/key" = {
        path = "${config.home.homeDirectory}/.oci/oci_api_key.pem";
        mode = "0600";
      };
      "oci/user" = {};
      "oci/tenancy" = {};
      "oci/fingerprint" = {};
      "oci/region" = {};
      "openmeteo/api/key" = {};
      "neocities" = {};
      # Google OAuth client for calendar sync. `key` names the nested path in the
      # sops file, so the pair stays grouped there while the secret path stays
      # slash-free. This replaced vdirsyncer scraping a hand-made rclone.conf.
      "gdrive_client_id".key = "googleDrive/clientId";
      "gdrive_client_secret".key = "googleDrive/clientSecret";
      # The fleet's one shell history. Rendered to atuin's default path, because
      # a bare `atuin` run mints a fresh key there when the file is missing and
      # that host then syncs a history nobody can decrypt. The key file wants
      # the base64 form, `atuin login -k` the mnemonic — two representations,
      # not interchangeable: `.agents/skills/atuin/SKILL.md`.
      "atuin-key" = {
        key = "atuin/key_base64";
        path = "${config.home.homeDirectory}/.local/share/atuin/key";
        mode = "0600";
      };
      "atuin-password" = {
        key = "atuin/password";
        mode = "0600";
      };
      "atuin-mnemonic" = {
        key = "atuin/key";
        mode = "0600";
      };
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
      # 0600 for the CLI's own check: it warns "Permissions on <config> are too
      # open" on every command at 0644, and the file names the key it trusts.
      "ociconfig" = {
        content = ''
          [DEFAULT]
          user = ${config.sops.placeholder."oci/user"}
          fingerprint = ${config.sops.placeholder."oci/fingerprint"}
          tenancy = ${config.sops.placeholder."oci/tenancy"}
          region = ${config.sops.placeholder."oci/region"}
          key_file = ${config.home.homeDirectory}/.oci/oci_api_key.pem
        '';
        mode = "0600";
      };
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
        accept-flake-config = true
        extra-substituters = https://install.determinate.systems
        extra-trusted-public-keys = cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM=
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
      SOPS_AGE_KEY_FILE =
        if useTpm
        then tpm_key_path
        else default_key_path;
    };
    packages = with pkgs;
      [
        sops
        yq-go
      ]
      ++ lib.optional useTpm pkgs.age-plugin-tpm;
    file = {
      ".aws/credentials".source = config.lib.file.mkOutOfStoreSymlink "${config.sops.templates."awscredentials".path}";
      # ~/.oci, not ~/.config/oci: `oci` reads $HOME/.oci/config, and the Cloud
      # Shell snippets and the SDKs all default to the same path.
      ".oci/config".source = config.lib.file.mkOutOfStoreSymlink "${config.sops.templates."ociconfig".path}";
    };
  };
}
