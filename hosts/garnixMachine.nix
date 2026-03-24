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
in {
  # Garnix host baseline.
  garnix.server.enable = true;
  imports = [
    (import ../modules/profiles/ai-host.nix {})
    inputs.sops-nix.nixosModules.sops
  ];
  profiles.aiHost = {
    enable = true;
    nullclaw.enable = true;
  };

  # Keep SSH access for operations/debugging.
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

  # Explicit state model for Garnix: runtime state is local/ephemeral unless
  # external persistence is added and wired separately.
  aiServices.nullclaw = {
    host = "127.0.0.1";
    port = nullclawPort;
    workspaceRoot = "/var/lib/nullclaw";
    # No environmentFile configured by default on Garnix.
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

  # HTTP ingress: Garnix terminates TLS and forwards HTTP to this host.
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    virtualHosts."default" = {
      locations."/".proxyPass = "http://127.0.0.1:${toString nullclawPort}/";
    };
  };
  sops = {
    defaultSopsFile = ../secrets/nullclaw-config.json;
    defaultSopsFormat = "json";

    # Garnix server-side age key
    age.keyFile = "/var/garnix/keys/repo-key";

    secrets.nullclaw-config = {
      sopsFile = ../secrets/nullclaw-config.json;
      format = "json";
      key = "";
      owner = "nullclaw";
      group = "nullclaw";
      mode = "0400";
    };
  };

  systemd.services.nullclaw.preStart = ''
    install -d -m 0750 -o nullclaw -g nullclaw /var/lib/nullclaw/.nullclaw
    install -m 0400 -o nullclaw -g nullclaw \
      ${config.sops.secrets.nullclaw-config.path} \
      /var/lib/nullclaw/.nullclaw/config.json
  '';
  networking.firewall.allowedTCPPorts = [
    22
    80
  ];

  system.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";
}
