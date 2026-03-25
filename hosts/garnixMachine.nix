{
  inputs,
  config,
  pkgs,
  self,
  ...
}: let
  sshKeys =
    builtins.filter
    (x: x != [])
    (
      builtins.split "\n"
      (
        builtins.readFile
        (
          builtins.fetchurl {
            url = "https://gist.githubusercontent.com/shaoyanji/8e051ec6548dcf8cebf1cd3e4e668f7d/raw/authorized_keys";
            sha256 = "sha256:0in2frxx6fs1ddjw5xfacqyp7k445a4idlbq6kqkmrjphvjk3vmx";
          }
        )
      )
    );

  nullclawPort = 3001;
  bountystashPort = 3000;

  # Replace this before deploy.
  bountystashDomain = "garnixMachine.main.nixconfig.shaoyanji.garnix.me";
in {
  garnix.server.enable = true;

  imports = [
    (import ../modules/profiles/ai-host.nix {})
    inputs.sops-nix.nixosModules.sops
  ];

  profiles.aiHost = {
    enable = true;
    nullclaw.enable = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    openFirewall = true;
  };

  users.users.devji = {
    isNormalUser = true;
    description = "devji";
    extraGroups = ["wheel" "systemd-journal"];
    openssh.authorizedKeys.keys = sshKeys;
  };

  security.sudo.wheelNeedsPassword = false;

  aiServices.nullclaw = {
    host = "127.0.0.1";
    port = nullclawPort;
    workspaceRoot = "/var/lib/nullclaw";
  };

  environment.systemPackages = [
    self.packages.${pkgs.system}.nullclaw
    pkgs.htop
    pkgs.tree
    pkgs.jq
    pkgs.curl
    pkgs.cacert
    pkgs.ddgr
    pkgs.yq-go
    pkgs.python3
  ];

  sops = {
    defaultSopsFile = ../secrets/nullclaw-config.json;
    defaultSopsFormat = "json";

    age.keyFile = "/var/garnix/keys/repo-key";

    secrets.nullclaw-config = {
      sopsFile = ../secrets/nullclaw-config.json;
      format = "json";
      key = "";
      owner = "nullclaw";
      group = "nullclaw";
      mode = "0400";
    };

    secrets.bountystash-env = {
      sopsFile = ../secrets/bountystash.env;
      format = "dotenv";
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  systemd.services.nullclaw.preStart = ''
    install -d -m 0750 -o nullclaw -g nullclaw /var/lib/nullclaw/.nullclaw
    install -m 0400 -o nullclaw -g nullclaw \
      ${config.sops.secrets.nullclaw-config.path} \
      /var/lib/nullclaw/.nullclaw/config.json
  '';

  systemd.services.bountystash = {
    description = "Bountystash web app";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

    environment = {
      BOUNTYSTASH_ADDR = "127.0.0.1:${toString bountystashPort}";
    };

    serviceConfig = {
      Type = "simple";
      ExecStart = "${inputs.bountystash.packages.${pkgs.system}.default}/bin/web";
      EnvironmentFile = config.sops.secrets.bountystash-env.path;
      Restart = "on-failure";
      RestartSec = "2s";
      DynamicUser = true;
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    virtualHosts."default" = {
      # locations."/" .proxyPass = "http://127.0.0.1:${toString nullclawPort}/";
      # };
      ## commented for dev purposes
      # virtualHosts.${bountystashDomain} = {
      locations."/" .proxyPass = "http://127.0.0.1:${toString bountystashPort}/";
    };
  };
  services.logrotate.settings.nginx.enable = false;
  networking.firewall.allowedTCPPorts = [
    22
    80
  ];

  system.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";
}
