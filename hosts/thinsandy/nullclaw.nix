{
  config,
  pkgs,
  ...
}: let
  nullclawPkg = pkgs.callPackage ../../pkgs/nullclaw.nix {};
in {
  users.groups.nullclaw = {};

  users.users.nullclaw = {
    isSystemUser = true;
    group = "nullclaw";
    home = "/var/lib/nullclaw";
    createHome = true;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/nullclaw 0750 nullclaw nullclaw -"
    "d /var/lib/nullclaw/.nullclaw 0750 nullclaw nullclaw -"
    "d /var/lib/nullclaw/workspace 0750 nullclaw nullclaw -"
  ];

  systemd.services.nullclaw = {
    description = "NullClaw Gateway";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    path =
      config.environment.systemPackages
      ++ (with pkgs; [
        curl
        cacert
      ]);
    serviceConfig = {
      User = "nullclaw";
      Group = "nullclaw";
      WorkingDirectory = "/var/lib/nullclaw";
      ExecStart = "${nullclawPkg}/bin/nullclaw gateway --host 127.0.0.1 --port 3001";
      Restart = "always";
      RestartSec = "5s";

      Environment = [
        "HOME=/var/lib/nullclaw"
        "NULLCLAW_HOME=/var/lib/nullclaw/.nullclaw"
        "NULLCLAW_WORKSPACE=/var/lib/nullclaw/workspace"
      ];
      EnvironmentFile = [config.sops.secrets."nullclaw".path];

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = ["/var/lib/nullclaw"];
    };
  };
  sops.secrets.nullclaw = {
    owner = "nullclaw";
    group = "nullclaw";
    mode = "0400";
  };
}
