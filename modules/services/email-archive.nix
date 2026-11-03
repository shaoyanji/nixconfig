# NpgsqlRest over a full-text email archive: loopback API, declared PostgreSQL
# role, attachments on disk and an optional Google Drive mirror.
# docs/email-archive.md.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.emailArchive;

  # The rclone remote is state, not config, for the same reason the calendar's
  # OAuth token is (modules/calendar.nix): a token exists only after a consent
  # flow, so no declaration can carry it. Nix owns the unit and the condition;
  # the operator owns one file, and the remote's client id/secret are the pair
  # already in sops (`googleDrive/*`) rather than a second credential.
  rcloneConfig = "${cfg.stateDir}/rclone.conf";

  attachmentsDir = "${cfg.stateDir}/attachments";

  # HTML-only mail is the majority of bulk mail; without a converter the row
  # stores a null body and is unsearchable. The same binary backs the gate.
  html2markdown = import ../scripts/html2markdown.nix {inherit pkgs;};

  # The importer reads the login user's himalaya config, because that is where
  # the IMAP account and its password command live; nothing else in the module
  # needs the user constants.
  user = import ../global/user.nix;

  # Upstream publishes one self-contained NativeAOT binary per arch; it links
  # only libc/libm, so autoPatchelfHook is the whole packaging story.
  npgsqlrest = pkgs.stdenv.mkDerivation rec {
    pname = "npgsqlrest";
    version = "3.21.0";

    src = pkgs.fetchurl {
      url = "https://github.com/NpgsqlRest/NpgsqlRest/releases/download/v${version}/npgsqlrest-linux-arm64";
      hash = "sha256-KoClZh7kJ8Px/oPNAhGD9ps8nfNEGyC/5BPRgTNQ+uE=";
    };

    # NativeAOT links libc/libm statically and dlopens TLS and GSSAPI at run
    # time, so these never appear as NEEDED entries: they have to be on the
    # RPATH or the process aborts with "No usable version of libssl was found".
    nativeBuildInputs = [pkgs.autoPatchelfHook];
    buildInputs = [pkgs.stdenv.cc.cc.lib];
    # `.out` explicitly: openssl's first output is `bin`, whose `lib/` is empty,
    # so naming the package alone yields an RPATH that cannot resolve libssl.
    runtimeDependencies = [
      pkgs.openssl.out
      pkgs.krb5
      pkgs.zlib
    ];
    dontUnpack = true;

    installPhase = ''
      install -Dm755 $src $out/bin/npgsqlrest
    '';

    meta = {
      description = "Automatic REST API for PostgreSQL";
      homepage = "https://npgsqlrest.github.io";
      license = lib.licenses.mit;
      platforms = ["aarch64-linux"];
      mainProgram = "npgsqlrest";
    };
  };

  settings = {
    Urls = "http://127.0.0.1:${toString cfg.port}";
    Config = {
      ParseEnvironmentVariables = true;
      AddEnvironmentVariables = false;
      EnvFile = null;
      ValidateConfigKeys = "Warning";
    };
    ConnectionStrings.Default = "Host=127.0.0.1;Port=5432;Database=${cfg.database};Username=${cfg.userName};Password={!PGPASSWORD}";
    DataProtection = {
      Storage = "FileSystem";
      FileSystemPath = "${cfg.stateDir}/data-protection-keys";
    };
    HealthChecks = {
      Enabled = true;
      Path = "/health";
      IncludeDatabaseCheck = true;
    };
    NpgsqlRest = {
      # Defaults are `/api/emails` behind an authorization scheme nothing
      # configures, and `OnlyAnnotated` comments (so a plain table yields no
      # endpoints at all — the enum has no `All`, an invalid value falls back to
      # the default). One dedicated database, so every public object is
      # published, and the tailnet is the boundary.
      # `/api` is the default and the only prefix that produces reachable
      # routes: `""` builds paths with no leading slash and every request 404s.
      UrlPathPrefix = "/api";
      CommentsMode = "ParseAll";
      IncludeSchemas = ["public"];
      RequiresAuthorization = false;
      # NpgsqlRest removed table CRUD in 3.14 ("exposing raw tables directly is
      # a questionable engineering practice"): endpoints come from SQL files or
      # routines. These files are the API, and they are type-checked against the
      # schema at startup.
      SqlFileSource = {
        Enabled = true;
        FilePattern = "${endpointsDir}/*.sql";
        ErrorMode = "Exit";
      };
      # A machine-readable contract, so an agent (or a rival implementation on
      # another port) can read the API instead of scraping this file. The route
      # is the artifact: a generated file beside the state dir would be a second
      # copy that goes stale the moment an endpoint changes.
      OpenApiOptions = {
        Enabled = true;
        FileName = null;
        UrlPath = "/openapi.json";
        DocumentTitle = "email-archive";
        DocumentDescription = "NpgsqlRest over the archived mailbox: list, full-text search, ingest.";
      };
      UploadOptions = {
        Enabled = true;
        LogUploadEvent = true;
        UploadHandlers = {
          FileSystemPath = attachmentsDir;
          FileSystemUseUniqueFileName = true;
          FileSystemCreatePathIfNotExists = true;
        };
      };
    };
  };

  appSettings = (pkgs.formats.json {}).generate "npgsqlrest-appsettings.json" settings;

  # Every option crosses as an argv entry, so no prose from a value can become
  # shell. `--dry-run` and friends still reach the script through "$@".
  importer = pkgs.writeShellApplication {
    name = "email-archive-import";
    runtimeInputs = [pkgs.python3 pkgs.himalaya pkgs.coreutils html2markdown];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./email-archive-import.py} \
        --api ${lib.escapeShellArg "http://127.0.0.1:${toString cfg.port}"} \
        --himalaya-config ${lib.escapeShellArg cfg.importer.himalayaConfig} \
        --account ${lib.escapeShellArg cfg.importer.account} \
        --mailbox ${lib.escapeShellArg cfg.importer.mailbox} \
        --attachments ${lib.escapeShellArg attachmentsDir} \
        --html2markdown ${html2markdown}/bin/html2markdown \
        --limit ${toString cfg.importer.limit} \
        --max-pages ${toString cfg.importer.maxPages} \
        --page-size ${toString cfg.importer.pageSize} \
        "$@"
    '';
  };

  # Triage writes verdicts, never mail: it reads what the importer stored and
  # posts one row per message to /api/triage-upsert. docs/email-archive.md.
  # Declared plugins become one JSON rule file. A plugin exists once a rule
  # routes to its owner, and this file is the only place a new one is added.
  pluginRules = (pkgs.formats.json {}).generate "email-archive-plugins.json" (
    lib.mapAttrs (name: plugin: {
      label = plugin.label;
      rules =
        map (rule: {
          owner =
            if rule.owner != ""
            then rule.owner
            else "agent:${name}";
          inherit (rule) tier senders subjects;
        })
        plugin.rules;
    })
    cfg.plugins
  );

  # Endpoints from the core and from every plugin, in one directory: NpgsqlRest
  # reads a single file pattern, and a plugin that cannot publish an endpoint is
  # not a plugin. A duplicate filename is a build error, not a silent override.
  endpointsDir = pkgs.runCommand "email-archive-endpoints" {} ''
    mkdir -p $out
    cp ${./email-archive-endpoints}/*.sql $out/
    ${lib.concatMapStringsSep "\n" (dir: "cp ${dir}/*.sql $out/") (
      lib.concatMap (plugin: plugin.sql) (lib.attrValues cfg.plugins)
    )}
  '';

  pluginSchemas = lib.concatMap (plugin: plugin.schema) (lib.attrValues cfg.plugins);

  # Declared pointers: an agent's regular "look here", one file the classifier
  # reads. Empty by default, so a host that wants none carries no state.
  pointers = pkgs.writeText "email-archive-pointers" (
    lib.concatStringsSep "\n" cfg.triage.pointers + "\n"
  );

  classifier = pkgs.writeShellApplication {
    name = "email-archive-triage";
    runtimeInputs = [pkgs.python3];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./email-triage.py} \
        --api ${lib.escapeShellArg "http://127.0.0.1:${toString cfg.port}"} \
        --classifier ${lib.escapeShellArg cfg.triage.classifier} \
        --plugins ${lib.escapeShellArg "${pluginRules}"} \
        --limit ${toString cfg.triage.limit} \
        --vip-file ${lib.escapeShellArg cfg.triage.vipFile} \
        --pointers ${lib.escapeShellArg "${pointers}"} \
        --engine-url ${lib.escapeShellArg cfg.triage.engineUrl} \
        --second-engine-url ${lib.escapeShellArg cfg.triage.secondEngineUrl} \
        --second-classifier ${lib.escapeShellArg cfg.triage.secondClassifier} \
        --margin ${toString cfg.triage.margin} \
        --expire-days ${toString cfg.triage.expireDays} \
        "$@"
    '';
  };

  # The queue's drainer: it runs after the classifier, so a CI notice never waits
  # for a person who was never going to act on it.
  ciDrain = pkgs.writeShellApplication {
    name = "email-archive-ci-drain";
    runtimeInputs = [pkgs.python3];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./email-ci-drain.py} \
        --api ${lib.escapeShellArg "http://127.0.0.1:${toString cfg.port}"} \
        "$@"
    '';
  };

  dbInit = pkgs.writeShellScript "email-archive-db-init" ''
    set -euo pipefail
    export PATH="${lib.makeBinPath [config.services.postgresql.finalPackage pkgs.coreutils]}:$PATH"

    password="$(cat "$CREDENTIALS_DIRECTORY/db-password")"

    # The role's password is not something ensureUsers can set, and it has to be
    # re-asserted on every activation so a rotated sops value lands. Ownership
    # is asserted here too: `ensureDBOwnership` only accepts a database named
    # after the role, and this one is not.
    psql -v ON_ERROR_STOP=1 -v pw="$password" -d postgres <<'SQL'
    ALTER ROLE ${cfg.userName} WITH LOGIN PASSWORD :'pw';
    ALTER DATABASE ${cfg.database} OWNER TO ${cfg.userName};
    SQL

    # Connect the way the app connects, so a wrong pg_hba rule fails here rather
    # than as a pod that starts and answers 500 for every endpoint.
    PGPASSWORD="$password" psql -v ON_ERROR_STOP=1 \
      -h 127.0.0.1 -U ${cfg.userName} -d ${cfg.database} -f ${./email-archive.sql} \
    ${lib.concatMapStringsSep "" (file: "  -f ${file} \\\n") pluginSchemas}      >/dev/null
  '';
in {
  options.services.emailArchive = {
    enable = lib.mkEnableOption "the NpgsqlRest email archive";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Loopback port the API listens on; the tailnet front is a `tailscale serve` mount.";
    };

    database = lib.mkOption {
      type = lib.types.str;
      default = "email_archive";
      description = "Database holding the archive.";
    };

    userName = lib.mkOption {
      type = lib.types.str;
      default = "npgsqlrest";
      description = "PostgreSQL role and system user the API runs as. Owns the database.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/npgsqlrest";
      description = "Working directory: appsettings, data-protection keys and the attachment tree.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = npgsqlrest;
      description = "NpgsqlRest binary.";
    };

    gdrive = {
      enable = lib.mkEnableOption "the hourly attachment mirror to Google Drive";

      remote = lib.mkOption {
        type = lib.types.str;
        default = "gdrive-email";
        description = "rclone remote name, defined by the operator in the service user's rclone.conf.";
      };

      folder = lib.mkOption {
        type = lib.types.str;
        default = "email-archive/attachments";
        description = "Destination path inside the remote.";
      };
    };

    importer = {
      enable = lib.mkEnableOption "the mailbox importer";

      account = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "himalaya account to read; empty uses the account marked default.";
      };

      mailbox = lib.mkOption {
        type = lib.types.str;
        default = "inbox";
        description = ''
          Mailbox to import. It is also what the row carries as a label, so
          importing two folders marks the rows by source.
        '';
      };

      limit = lib.mkOption {
        type = lib.types.ints.positive;
        default = 100;
        description = ''
          New messages one run imports. There is no watermark: each run takes
          the newest not-yet-archived messages, so successive runs walk further
          back through the mailbox until it is exhausted.
        '';
      };

      maxPages = lib.mkOption {
        type = lib.types.ints.positive;
        default = 20;
        description = "Envelope pages a run may scan before giving up.";
      };

      pageSize = lib.mkOption {
        type = lib.types.ints.positive;
        default = 100;
        description = "Envelopes per page.";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "hourly";
        description = "OnCalendar expression for the import timer.";
      };

      himalayaConfig = lib.mkOption {
        type = lib.types.str;
        default = "${user.home}/.config/himalaya/config.toml";
        description = ''
          himalaya config the importer reads. It belongs to the login user and
          carries the account password as a command, which is why the unit runs
          as root rather than as the archive service user.
        '';
      };
    };

    plugins = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          label = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Human name for this plugin, used in reports.";
          };
          rules = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                senders = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [];
                  description = "Addresses or domains this rule claims (substring of the sender).";
                };
                subjects = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [];
                  description = ''
                    Subject markers this rule claims, lowercased substrings. A
                    plugin that owns a conversation needs this: a recruiter
                    answers from the company's own mailbox, not from the ATS.
                  '';
                };
                owner = lib.mkOption {
                  type = lib.types.str;
                  default = "";
                  description = "Owner recorded on the verdict; defaults to `agent:<plugin>`.";
                };
                tier = lib.mkOption {
                  type = lib.types.enum ["person" "action" "digest"];
                  default = "action";
                  description = ''
                    `action` keeps the mail in the plugin's queue, `digest` files
                    it for a weekly read, `person` puts it in front of a human —
                    which a plugin should rarely claim.
                  '';
                };
              };
            });
            default = [];
            description = "Sender rules. A plugin with none claims nothing.";
          };
          sql = lib.mkOption {
            type = lib.types.listOf lib.types.path;
            default = [];
            description = "Directories of endpoint `.sql` files this plugin publishes.";
          };
          schema = lib.mkOption {
            type = lib.types.listOf lib.types.path;
            default = [];
            description = ''
              DDL files applied after the core schema on every activation — so
              every statement in them must be idempotent. A plugin owns its own
              tables; the core does not know their names.
            '';
          };
          packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [];
            description = "Tools the plugin's operator and agent commands need on PATH.";
          };
        };
      });
      default = {};
      description = ''
        The hub's plugin contract. A plugin declares what mail it claims (rules),
        what the archive publishes on its behalf (sql, schema) and what it needs
        to run (packages); `GET /api/plugins` reports every owner's queue depth.

        CI is the only built-in, because its rule is a subject pattern rather
        than a sender. Everything else — the job pipeline included — is a guest:
        its module lives outside `modules/services`, and removing it removes its
        tables, endpoints and routing in one edit.
      '';
    };

    triage = {
      enable = lib.mkEnableOption "the mail triage classifier";

      classifier = lib.mkOption {
        type = lib.types.str;
        default = "rules+engine";
        description = ''
          Name recorded on every verdict. It is half the primary key, so a
          second classifier writes beside this one instead of overwriting it.
          Bump it when the rules change in a way that should re-judge the
          archive: a new name starts from an empty gap.
        '';
      };

      limit = lib.mkOption {
        type = lib.types.ints.positive;
        default = 500;
        description = "Messages one run judges. Only messages with no verdict are fetched.";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* *:45:00";
        description = ''
          OnCalendar expression for the triage timer. Offset from the hour
          because the importer runs on the hour with a delay, and triage has
          nothing to do until it lands.
        '';
      };

      vipFile = lib.mkOption {
        type = lib.types.str;
        default = config.sops.secrets."email-archive/vip-senders".path;
        description = ''
          Addresses that are always a person. Declarative: the list lives in
          `modules/secrets.yaml` under `email-archive.vip-senders` (commas or
          newlines separate entries) and sops-nix lands it as a 0400 file the
          classifier reads as root. A family address in a public tree would be a
          leak, which is why it is encrypted rather than written into this file.
          Changing it is a sops edit plus a rebuild, not a state file to forget.
        '';
      };

      engineUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:8091";
        description = ''
          The decision engine the residue goes to (services.systemoneDecision).
          Loopback by default, so mail metadata stays on this host.
        '';
      };

      secondEngineUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:8092";
        description = ''
          The second architecture (`services.systemoneDecision.serve.secondary`).
          The triage asks both and they override each other: a definite verdict
          replaces the other model's in either direction, and only a tie keeps the
          tier `julia` assigned. An unreachable second engine skips the pass.
        '';
      };

      margin = lib.mkOption {
        type = lib.types.float;
        default = 0.10;
        description = ''
          How far the engine's top choice must lead the runner-up before the
          verdict is trusted; below it the message becomes `review`, which is
          surfaced to a person rather than hidden. A margin, not an absolute
          probability: julia-1 reports low probabilities even when right.
        '';
      };

      secondClassifier = lib.mkOption {
        type = lib.types.str;
        # Carries the first classifier's name so one bump re-reads both. Without
        # that, a bumped first pass writes new verdicts over rows the second pass
        # believes it already judged, and the queue grows by the difference.
        default = "second:${cfg.triage.classifier}";
        defaultText = lib.literalExpression ''"second:''${config.services.emailArchive.triage.classifier}"'';
        description = ''
          Name recorded on the second model's verdicts. Like `classifier`, it is
          half the primary key: a change to what the pass *means* re-reads the
          archive, and the default ties it to `classifier` so the pair moves
          together.
        '';
      };

      pointers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Addresses whose mail is an agent's regular pointer: tier `action`, owner
          `human`, exempt from the feed rule and never closed by the second model.
          One email a day that says "look here" is not bulk; a thousand of them is
          what this exemption would look like if it were misused.
        '';
      };

      expireDays = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 30;
        description = ''
          Resolve `review` rows older than this many days. A message neither model
          can place, untouched for a month, stays archived and searchable; it just
          stops being parked in front of a person. `person`, `action` and a
          declared pointer are never expired. 0 keeps them forever.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # On PATH so `task checks:email:bodies` resolves the same converter the
    # importer runs, with no second pin.
    environment.systemPackages =
      lib.optional cfg.importer.enable html2markdown
      ++ lib.optional cfg.triage.enable classifier
      ++ lib.optional cfg.triage.enable ciDrain
      ++ lib.concatMap (plugin: plugin.packages) (lib.attrValues cfg.plugins);

    services.postgresql = {
      enable = true;
      ensureDatabases = [cfg.database];
      ensureUsers = [
        {
          name = cfg.userName;
        }
      ];
      # Local socket stays trust so `sudo -u postgres psql` works; the app's TCP
      # connection is the only authenticated path, and it is loopback-only.
      authentication = ''
        local all all trust
        host  all all 127.0.0.1/32 scram-sha-256
        host  all all ::1/128      scram-sha-256
      '';
    };

    sops.secrets."email-archive/db-password" = {
      sopsFile = ../secrets.yaml;
      mode = "0400";
    };

    # The VIP list is declarative and encrypted: the value never appears in this
    # tree, and sops-nix is what lands it. The classifier runs as root and reads
    # this path (triage.vipFile), so no copy exists on disk to drift.
    sops.secrets."email-archive/vip-senders" = {
      sopsFile = ../secrets.yaml;
      mode = "0400";
    };

    sops.templates."npgsqlrest.env" = {
      content = ''
        PGPASSWORD=${config.sops.placeholder."email-archive/db-password"}
      '';
      owner = cfg.userName;
      mode = "0400";
    };

    users.users.${cfg.userName} = {
      isSystemUser = true;
      group = cfg.userName;
      home = cfg.stateDir;
    };
    users.groups.${cfg.userName} = {};

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0750 ${cfg.userName} ${cfg.userName} -"
      "d ${attachmentsDir} 0750 ${cfg.userName} ${cfg.userName} -"
      "d ${cfg.stateDir}/data-protection-keys 0700 ${cfg.userName} ${cfg.userName} -"
      # `L+` because the target carries a store hash: a rebuild must retarget it.
      "L+ ${cfg.stateDir}/appsettings.json - - - - ${appSettings}"
    ];

    systemd.services.email-archive-db-init = {
      description = "Apply the email archive schema and role password";
      wantedBy = ["multi-user.target"];
      # ensureUsers/ensureDatabases run in postgresql-setup, which is ordered
      # *after* the server: waiting on postgresql.service alone races the role.
      after = ["postgresql-setup.service"];
      requires = ["postgresql-setup.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
        LoadCredential = "db-password:${config.sops.secrets."email-archive/db-password".path}";
        ExecStart = dbInit;
      };
    };

    systemd.services.npgsqlrest = {
      description = "NpgsqlRest API for the email archive";
      unitConfig.X-Fleet-Role = "daemon";
      wantedBy = ["multi-user.target"];
      after = [
        "postgresql.service"
        "email-archive-db-init.service"
        "network.target"
      ];
      requires = ["email-archive-db-init.service"];
      # The settings live behind a symlink, which systemd cannot diff: without
      # this a config change lands on disk and never reaches the process.
      restartTriggers = [appSettings];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/npgsqlrest";
        User = cfg.userName;
        Group = cfg.userName;
        WorkingDirectory = cfg.stateDir;
        StateDirectory = "npgsqlrest";
        EnvironmentFile = [config.sops.templates."npgsqlrest.env".path];
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
      };
    };

    # One-way by design: Drive holds a mirror, never the source of truth. The
    # unit is skipped — not failed — on a host with no remote yet, so the timer
    # ticks from the first boot and the mirror starts the moment a token exists.
    systemd.services.email-archive-gdrive-sync = lib.mkIf cfg.gdrive.enable {
      description = "Mirror email attachments to Google Drive";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      unitConfig.ConditionPathExists = rcloneConfig;
      serviceConfig = {
        Type = "oneshot";
        User = cfg.userName;
        Group = cfg.userName;
        ExecStart = "${pkgs.rclone}/bin/rclone --config ${rcloneConfig} sync ${attachmentsDir} ${cfg.gdrive.remote}:${cfg.gdrive.folder} --create-empty-src-dirs --log-level INFO --stats-one-line";
      };
    };

    systemd.timers.email-archive-gdrive-sync = lib.mkIf cfg.gdrive.enable {
      description = "Hourly email attachment mirror";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };

    # An empty archive is not an archive: the mailbox is the source of truth and
    # the timer walks it, while the endpoint's upsert makes every re-run safe.
    systemd.services.email-archive-import = lib.mkIf cfg.importer.enable {
      description = "Import new mail into the email archive";
      after = ["npgsqlrest.service" "network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${importer}/bin/email-archive-import";
        # A backfill reads hundreds of messages over IMAP; the oneshot default
        # would kill the run partway through.
        TimeoutStartSec = "45min";
        StateDirectory = "email-archive-import";
        Environment = "HOME=/var/lib/email-archive-import";
        # root: the himalaya config and its password command belong to the login
        # user, and the attachment tree belongs to the archive service user.
        User = "root";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = [attachmentsDir];
      };
    };

    systemd.timers.email-archive-import = lib.mkIf cfg.importer.enable {
      description = "Hourly mail import";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.importer.schedule;
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
    };

    # Classification is a read of what the importer already stored, so it runs
    # after it and never gates it: a mailbox with no verdicts is still searchable.
    systemd.services.email-archive-triage = lib.mkIf cfg.triage.enable {
      description = "Classify archived mail into tiers and owners";
      after = ["npgsqlrest.service"];
      requires = ["npgsqlrest.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${classifier}/bin/email-archive-triage";
        # Judging and draining are the same hour's work: the classifier fills the
        # queues, this closes the CI notices no person will ever read. Prefixed
        # `-`: a drain that cannot reach the API must not mark the classifier red.
        ExecStartPost = "-${ciDrain}/bin/email-archive-ci-drain";
        StateDirectory = "email-archive-triage";
        User = "root";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    systemd.timers.email-archive-triage = lib.mkIf cfg.triage.enable {
      description = "Hourly mail triage";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.triage.schedule;
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };
  };
}
