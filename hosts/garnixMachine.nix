{
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

  networking.firewall.allowedTCPPorts = [
    22
    80
  ];

  system.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";
}
