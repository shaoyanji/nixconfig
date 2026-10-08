{
  inputs,
  config,
  pkgs,
  ...
}: let
  bountystashPort = 3000;
  bountystashLocalUpstream = "http://127.0.0.1:${toString bountystashPort}/";
in {
  garnix.server.enable = true;
  networking.hostName = "garnixMachine";

  imports = [
    ../modules/config/authorized-keys.nix
    inputs.sops-nix.nixosModules.sops
  ];

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
    openssh.authorizedKeys.keys = config.ssh.authorizedKeys.keys;
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = [
    pkgs.htop
    pkgs.tree
    pkgs.jq
    pkgs.curl
    pkgs.cacert
  ];

  sops = {
    age.keyFile = "/var/garnix/keys/repo-key";

    secrets.bountystash-env = {
      sopsFile = ../secrets/bountystash.env;
      format = "dotenv";
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  systemd.services.bountystash = {
    description = "Bountystash web app";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

    environment = {
      PORT = toString bountystashPort;
      # BOUNTYSTASH_ADDR = "127.0.0.1:${toString bountystashPort}";
    };

    serviceConfig = {
      Type = "simple";
      ExecStart = "${inputs.bountystash.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/web";
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
      locations."/" .proxyPass = bountystashLocalUpstream;
    };
  };
  services.dbus = {
    enable = true;
    implementation = "dbus";
  };
  assertions = [
    {
      assertion = config.services.nginx.virtualHosts.default.locations."/".proxyPass == bountystashLocalUpstream;
      message = "garnixMachine default public nginx upstream is expected to target bountystash";
    }
  ];
  services.logrotate.settings.nginx.enable = false;
  networking.firewall.allowedTCPPorts = [
    22
    80
  ];

  system.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";

  nix.settings.experimental-features = ["nix-command" "flakes"];
}
