# appflow — a guest of the mail hub, declared through the `services.emailArchive.plugins`
# contract (tables, endpoints, sender rules, tooling).
# docs: modules/plugins/appflow/README.md
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.appflowPlugin;
  user = import ../../global/user.nix;

  sync = pkgs.writeShellApplication {
    # himalaya is here for drafts only: a draft is written into the mailbox's
    # Drafts folder, and nothing in this plugin can send mail.
    name = "appflow-sync";
    runtimeInputs = [pkgs.python3 pkgs.himalaya];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./sync.py} \
        --api ${lib.escapeShellArg "http://127.0.0.1:${toString config.services.emailArchive.port}"} \
        --himalaya-config ${lib.escapeShellArg "${user.home}/.config/himalaya/config.toml"} \
        "$@"
    '';
  };

  # The senders this plugin claims. Kept as data so the classifier stays generic
  # and the list is reviewable in one place.
  atsSenders = [
    "greenhouse.io"
    "lever.co"
    "ashbyhq.com"
    "ashby.com"
    "personio."
    "join.com"
    "softgarden."
    "concludis"
    "recruitee.com"
    "smartrecruiters"
    "teamtailor"
    "workable.com"
    "icims"
    "successfactors"
  ];

  jobAlertSenders = ["indeed.com" "stepstone" "linkedin.com" "glassdoor" "xing.com"];
in {
  options.services.appflowPlugin = {
    enable = lib.mkEnableOption "the application pipeline plugin";

    import = {
      source = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          An `applications.json` to import on a timer. Empty means on demand
          (`task agents:apps:import FILE=…`), which is the state once this
          database is the source of truth.
        '';
      };
      schedule = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 03:20:00";
        description = "OnCalendar expression for the import timer (only used with `source`).";
      };
      link = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Match archived mail to applications on every import run.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.emailArchive.plugins.appflow = {
      label = "job application pipeline";
      sql = [./sql];
      schema = [./schema.sql];
      packages = [sync];
      rules = [
        {
          # Application mail is the pipeline's: the tracker moves with it.
          senders = atsSenders;
          tier = "action";
          owner = "agent:apps";
        }
        {
          # Job alerts are bulk, not lifecycle.
          senders = jobAlertSenders;
          tier = "digest";
          owner = "none";
        }
      ];
    };

    systemd.services.appflow-import = lib.mkIf (cfg.import.source != "") {
      description = "Import the job pipeline and link it to archived mail";
      after = ["npgsqlrest.service"];
      requires = ["npgsqlrest.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart =
          "${sync}/bin/appflow-sync --file ${lib.escapeShellArg cfg.import.source}"
          + lib.optionalString cfg.import.link " --link";
        StateDirectory = "appflow-import";
        User = "root";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
      };
    };

    systemd.timers.appflow-import = lib.mkIf (cfg.import.source != "") {
      description = "Nightly job pipeline import";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.import.schedule;
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
    };
  };
}
