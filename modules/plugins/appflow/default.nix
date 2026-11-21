# appflow — a guest of the mail hub, declared through the `services.emailArchive.plugins`
# contract (tables, endpoints, sender rules, tooling).
# docs: modules/plugins/appflow/README.md
{
  config,
  lib,
  pkgs,
  user,
  systemdJobs,
  ...
}: let
  cfg = config.services.appflowPlugin;

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

  # The resolver imports `sync` from its own directory, so both files land in one
  # store path; a single-file copy would break the import at activation.
  resolveSrc = pkgs.runCommand "appflow-resolve-src" {} ''
    mkdir -p $out
    cp ${./resolve.py} $out/resolve.py
    cp ${./sync.py} $out/sync.py
  '';

  resolve = pkgs.writeShellApplication {
    name = "appflow-resolve";
    runtimeInputs = [pkgs.python3];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${resolveSrc}/resolve.py \
        --api ${lib.escapeShellArg "http://127.0.0.1:${toString config.services.emailArchive.port}"} \
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
    "workable"
    "applytojob.com"
    "icims"
    "successfactors"
  ];

  jobAlertSenders = ["indeed.com" "stepstone" "linkedin.com" "glassdoor" "xing.com"];
  appflowImportJob = systemdJobs.mkTimerJob {} {
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
    timerDescription = "Nightly job pipeline import";
    onCalendar = cfg.import.schedule;
    randomizedDelaySec = "10m";
  };
  appflowSyncJob = systemdJobs.mkTimerJob {} {
    description = "Advance the job pipeline from ATS mail and close what it read";
    after = ["npgsqlrest.service"];
    requires = ["npgsqlrest.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/appflow-sync --sync --apply --ledger /var/lib/appflow-sync/apps-sync.jsonl";
      # The queue resolver reads what the sync just left. `--no-block` keeps
      # this unit green when a model or the agent fails: the resolver carries
      # its own result, and a sync that did its work is not a failed sync.
      ExecStartPost = [
        "${config.systemd.package}/bin/systemctl --no-block start appflow-resolve.service"
      ];
      Environment =
        lib.optionals (cfg.notify.url != "") [
          "NTFY_URL=${cfg.notify.url}"
          "NTFY_TOPIC=${cfg.notify.topic}"
          "NTFY_USER=${cfg.notify.user}"
        ]
        ++ lib.optional (cfg.notify.passwordFile != null)
        "NTFY_PASSWORD_FILE=${toString cfg.notify.passwordFile}";
      StateDirectory = "appflow-sync";
      User = "root";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
    };
    timerDescription = "Hourly job pipeline sync";
    onCalendar = cfg.sync.schedule;
    randomizedDelaySec = "5m";
  };
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

    # A queue with no drainer is a backlog with extra steps: the triage files
    # application mail here hourly, and this is what reads it. On by default, and
    # a run with an empty queue exits in a second.
    sync = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Advance the pipeline from the agent queue on a timer.";
      };
      schedule = lib.mkOption {
        type = lib.types.str;
        default = "hourly";
        description = "OnCalendar expression for the sync timer.";
      };
    };

    # A parked question is the one thing this plugin produces that a person has to
    # act on outside the mail client. The queue is the durable half; this is the
    # half that arrives. Empty `url` sends nothing, so a host with no push server
    # needs no configuration at all.
    notify = {
      url = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Push server base URL (ntfy). Empty disables the push.";
      };
      topic = lib.mkOption {
        type = lib.types.str;
        default = "fleet";
        description = "Topic the parked question is published to.";
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "User for HTTP basic auth; empty sends no credentials.";
      };
      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "File holding the password for `user`, so it never reaches argv.";
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
          # Application mail is the pipeline's: the tracker moves with it. A
          # recruiter answers from the employer's own mailbox, so the sender list
          # cannot be the only door — 42 of the 511 rows in the human queue were
          # application mail that named the company but not an ATS.
          senders = atsSenders;
          subjects = [
            "bewerbung"
            "bewerbungsprozess"
            "lebenslauf"
            "kandidat"
            "eeo self-identification"
            "your application"
            "application received"
            "application status"
            "application:"
            "job application"
            "resume received"
            "thank you for applying"
          ];
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

    systemd.services.appflow-import = lib.mkIf (cfg.import.source != "") appflowImportJob.service;

    systemd.timers.appflow-import = lib.mkIf (cfg.import.source != "") appflowImportJob.timer;

    # The drainer: same verbs an operator runs by hand, on a schedule, so the
    # queue is empty when a person looks instead of waiting for someone to notice.
    systemd.services.appflow-sync = lib.mkIf cfg.sync.enable appflowSyncJob.service;

    systemd.timers.appflow-sync = lib.mkIf cfg.sync.enable appflowSyncJob.timer;

    # Rules, a ternary from the two System One engines, then exactly one hermes
    # turn for the unsures. It runs as the login user because hermes and its
    # provider config live in the per-user profile and `~/.hermes`; a root unit
    # would find neither. The ledger is state, not a home dotfile.
    systemd.services.appflow-resolve = lib.mkIf cfg.sync.enable {
      description = "Attribute or close the appflow queue with one model batch";
      after = ["npgsqlrest.service"];
      requires = ["npgsqlrest.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${resolve}/bin/appflow-resolve --apply --ledger /var/lib/appflow-resolve/apps-resolve.jsonl";
        StateDirectory = "appflow-resolve";
        User = user.name;
        Environment = [
          "HOME=${user.home}"
          "PATH=/etc/profiles/per-user/${user.name}/bin:/run/current-system/sw/bin"
        ];
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        # hermes reads ~/.hermes and writes its session state there.
        ProtectHome = false;
        TimeoutStartSec = "15min";
      };
    };
  };
}
