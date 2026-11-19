# modules/services/task-web.nix — fuzzy-find + run any `task` recipe over
# the tailnet (modules/services/service-portal.nix mounts); the tail IS
# the auth model, by design — /api/run + /api/shell never gate again.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.taskWeb;

  package = pkgs.buildGoModule {
    pname = "task-web";
    version = "0.1.0";
    src = ./task-web;
    # Standard library only — same choice as modules/services/turns-dashboard.nix.
    vendorHash = null;
    meta = {
      description = "Tailnet control plane over the Taskfile surface";
      mainProgram = "task-web";
    };
  };

  site = pkgs.runCommand "task-web-site" {} ''
    mkdir -p $out
    cp ${./task-web/web/index.html} $out/index.html
    cp ${./task-web/web/style.css} $out/style.css
    cp ${./task-web/web/app.js} $out/app.js
  '';

  home = config.users.users.${cfg.user}.home;
  repoDir =
    if cfg.repoDir != null
    then cfg.repoDir
    else "${home}/Documents/nixconfig";
in {
  options.services.taskWeb = {
    enable = lib.mkEnableOption "the tailnet task control plane (fuzzy task browser + runner)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8490;
      description = ''
        Loopback port task-web listens on. Published only through
        `services.servicePortal.mounts` — the registry's single declaration of
        what is reachable on the tailnet.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "devji";
      description = ''
        Account the service runs as. The login user on purpose: `task` recipes
        expect the operator's checkout, git identity and profile PATH — same
        reasoning as services.turnsDashboard.user.
      '';
    };

    repoDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Checkout the tasks run in. Null means `$HOME/Documents/nixconfig` of
        {option}`user` — the live fleet checkout on frieren.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.task-web = {
      description = "Tailnet task control plane (Taskfile browser + runner)";
      wantedBy = ["multi-user.target"];
      unitConfig.X-Fleet-Role = "daemon";
      after = ["network.target"];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = "users";
        WorkingDirectory = repoDir;
        ExecStart = "${lib.getExe package} -addr 127.0.0.1:${toString cfg.port} -repo ${repoDir} -site ${site}";
        Environment = [
          "HOME=${home}"
          # PATH mirrors modules/services/turns-dashboard.nix (profile = go-task, wrappers = sudo).
          "PATH=/run/wrappers/bin:${home}/.nix-profile/bin:/etc/profiles/per-user/${cfg.user}/bin:/run/current-system/sw/bin"
        ];
        Restart = "always";
        RestartSec = 3;

        # Unhardened on purpose — `task infra:*` writes /etc + /nix + /var
        # through sudo (modules/services/service-portal.nix is the fence).
        PrivateTmp = true;
        ProtectHome = false;
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
        MemoryMax = "512M";
      };
    };
  };
}
