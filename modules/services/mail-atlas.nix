# 信海圖 — the archive as a field: a reading surface, not a second mail store.
# Plugins are declared through `services.emailArchive.plugins`. docs/mail-atlas.md
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.mailAtlas;
  archive = config.services.emailArchive;

  # The particle simulation is a real .wat compiled at build time: the artifact
  # is a store path, wabt is a build input, and nothing is generated on the host.
  wasm =
    pkgs.runCommand "mail-atlas-wasm" {
      nativeBuildInputs = [pkgs.wabt];
    } ''
      mkdir -p $out
      wat2wasm ${./mail-atlas/site/particles.wat} -o $out/particles.wasm
    '';

  # The page writes ~30 Han glyphs. Relying on the reader's system fonts for
  # them is how the title becomes tofu boxes on a machine without CJK — so the
  # glyphs are cut out of Noto CJK TC at build time and served from the same
  # origin: 8.8 kB for 20 glyphs, a fraction of the 190 MB source collection.
  han =
    pkgs.runCommand "mail-atlas-han.woff" {
      nativeBuildInputs = [pkgs.python3Packages.fonttools];
    } ''
      printf '%s' '信海圖郵門網卷尋業商財器守文人行公錄總氣觀緣數時經讀靜' > glyphs.txt
      pyftsubset \
        ${pkgs.noto-fonts-cjk-sans}/share/fonts/opentype/noto-cjk/NotoSansCJK-VF.otf.ttc \
        --font-number=3 \
        --text-file=glyphs.txt \
        --flavor=woff \
        --layout-features="" \
        --no-hinting \
        --desubroutinize \
        --output-file=$out
    '';

  site = pkgs.runCommand "mail-atlas-site" {} ''
    mkdir -p $out
    cp ${./mail-atlas/site/index.html} $out/index.html
    cp ${./mail-atlas/site/style.css} $out/style.css
    cp ${./mail-atlas/site/app.js} $out/app.js
    cp ${./mail-atlas/site/particles.js} $out/particles.js
    cp ${wasm}/particles.wasm $out/particles.wasm
    cp ${han} $out/han.woff
  '';

  # The other end of a decision: the page writes rows, this executes the two
  # mechanical kinds through himalaya. It runs as root for the same reason the
  # importer does — the himalaya config and its password command belong to the
  # login user. `hermes` rows are an agent's to read, so they stay pending.
  drain = pkgs.writeShellApplication {
    name = "mail-atlas-drain";
    # `coreutils` is not decoration: the himalaya config reads its password with
    # a `cat …` command, and the unit's PATH is this list plus systemd's
    # `/usr/bin` — which does not exist on NixOS. Without it himalaya exits 1
    # with empty stderr and every decision stays pending forever.
    runtimeInputs = [pkgs.python3 pkgs.himalaya pkgs.coreutils];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./mail-atlas/drain.py} \
        --api ${lib.escapeShellArg "http://127.0.0.1:${toString archive.port}"} \
        --himalaya-config ${lib.escapeShellArg archive.importer.himalayaConfig} \
        --account ${lib.escapeShellArg archive.importer.account} \
        --mailbox ${lib.escapeShellArg archive.importer.mailbox} \
        --archive-mailbox ${lib.escapeShellArg cfg.drain.archiveMailbox} \
        --limit ${toString cfg.drain.limit} \
        ${lib.optionalString cfg.drain.dryRun "--dry-run"} \
        "$@"
    '';
  };

  # The mailbox is the truth about where a letter is: mail moved on a phone or
  # in the web client never reaches `mail_box`, so a periodic pass reads the
  # Inbox from himalaya and writes the difference back. Same credentials and
  # same reason for root as the drain.
  reconcile = pkgs.writeShellApplication {
    name = "mail-atlas-reconcile";
    runtimeInputs = [pkgs.python3 pkgs.himalaya pkgs.coreutils];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./mail-atlas/reconcile.py} \
        --api ${lib.escapeShellArg "http://127.0.0.1:${toString archive.port}"} \
        --himalaya-config ${lib.escapeShellArg archive.importer.himalayaConfig} \
        --account ${lib.escapeShellArg archive.importer.account} \
        --mailbox ${lib.escapeShellArg archive.importer.mailbox} \
        --page-size ${toString cfg.reconcile.pageSize} \
        --max-pages ${toString cfg.reconcile.maxPages} \
        "$@"
    '';
  };

  tagger = pkgs.writeShellScript "mail-atlas-tag" ''
    set -euo pipefail
    export PATH="${lib.makeBinPath [config.services.postgresql.finalPackage pkgs.coreutils]}:$PATH"

    # The same TCP path and role the API uses, so a wrong pg_hba rule fails here
    # instead of as a tagger that silently tags nothing.
    PGPASSWORD="$(cat "$CREDENTIALS_DIRECTORY/db-password")" \
      psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -U ${archive.userName} -d ${archive.database} \
        -tAc "select mail_atlas_autotag(${toString cfg.tagLimit})"
  '';
in {
  options.services.mailAtlas = {
    enable = lib.mkEnableOption "the mail atlas (fuzzy search, taxonomy and relation graph)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8085;
      description = ''
        Loopback port the static frontend listens on. It is not exposed: the
        host publishes it through `services.servicePortal.mounts`, which is the
        single declaration of what is reachable on the tailnet.
      '';
    };

    drain = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Execute the queue: archive and deletion decisions are carried out in
          the mailbox every few minutes. Hermes instructions are never executed
          here — they are a sentence for an agent.
        '';
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "*:0/5";
        description = ''
          OnCalendar expression for the drain timer. Decisions are interactive,
          so five minutes is the responsiveness the queue is worth; the run is a
          no-op when nothing is pending.
        '';
      };

      archiveMailbox = lib.mkOption {
        type = lib.types.str;
        default = "[Gmail]/All Mail";
        description = ''
          Where `archive` moves a message. Gmail has no Archive folder: dropping
          the Inbox label is what archiving means, and a move to All Mail is
          that edit.
        '';
      };

      dryRun = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Resolve every decision against the mailbox and close nothing. The
          journal then shows exactly which uid each row would act on.
        '';
      };

      limit = lib.mkOption {
        type = lib.types.ints.positive;
        default = 50;
        description = "Pending decisions one run may execute.";
      };
    };

    reconcile = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Keep `mail_box` in step with the real Inbox: a letter archived in
          Gmail (or on a phone) stops counting as inbox here, and one that comes
          back starts again. Without this the working set only ever grows with
          mail the person already dealt with.
        '';
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 04:20:00";
        description = ''
          OnCalendar expression for the reconcile timer. Nightly, and before the
          06:30 bulk sweep: the sweep decides against the working set, so it
          should be a set that already knows what left the Inbox by other means.
          The pass is a full envelope walk of the Inbox, which is a night job,
          not something to run against a mailbox while a person is using it.
        '';
      };

      pageSize = lib.mkOption {
        type = lib.types.ints.positive;
        default = 500;
        description = "Envelopes one IMAP page asks for; the whole Inbox is walked.";
      };

      maxPages = lib.mkOption {
        type = lib.types.ints.positive;
        default = 40;
        description = ''
          Page cap for one walk, i.e. 20 000 inbox letters at the default page
          size. Hitting it aborts the run instead of concluding from a partial
          set — the one failure that would empty the working set.
        '';
      };
    };

    tagLimit = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4000;
      description = ''
        Messages one tagger run may judge. A bounded run rather than one long
        transaction: a full backfill is a few runs of the timer.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # The two ends of the queue are operator commands as well as units: a person
    # asking "what would this do" runs the dry run by hand, and a task that
    # cannot find the binary on PATH is a task that lies about being available.
    environment.systemPackages =
      lib.optional cfg.drain.enable drain ++ lib.optional cfg.reconcile.enable reconcile;

    # The taxonomy, the tagging function and the four read endpoints, as a
    # plugin: the hub applies `schema.sql` after the core schema on every
    # activation and publishes `endpoints/` beside its own routes.
    services.emailArchive.plugins.mail-atlas = {
      label = "mail atlas";
      sql = [./mail-atlas/endpoints];
      schema = [./mail-atlas/schema.sql];
    };

    systemd.services.mail-atlas-tag = {
      description = "Tag archived mail against the mail-atlas taxonomy";
      after = ["npgsqlrest.service"];
      requires = ["npgsqlrest.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        LoadCredential = "db-password:${config.sops.secrets."email-archive/db-password".path}";
        ExecStart = tagger;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    # Offset from the hour: the importer runs at :00 with a delay and triage at
    # :45, so :50 tags the mail both of them just produced.
    systemd.timers.mail-atlas-tag = {
      description = "Hourly mail-atlas tagging";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*-*-* *:50:00";
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };

    systemd.services.mail-atlas-drain = lib.mkIf cfg.drain.enable {
      description = "Execute pending mail-atlas decisions through himalaya";
      after = ["npgsqlrest.service" "network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${drain}/bin/mail-atlas-drain";
        TimeoutStartSec = "15min";
        StateDirectory = "mail-atlas-drain";
        Environment = "HOME=/var/lib/mail-atlas-drain";
        User = "root";
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };

    systemd.timers.mail-atlas-drain = lib.mkIf cfg.drain.enable {
      description = "Drain the mail-atlas decision queue";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.drain.schedule;
        Persistent = true;
        RandomizedDelaySec = "20s";
      };
    };

    systemd.services.mail-atlas-reconcile = lib.mkIf cfg.reconcile.enable {
      description = "Reconcile the mail-atlas inbox with the real mailbox";
      after = ["npgsqlrest.service" "network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${reconcile}/bin/mail-atlas-reconcile";
        TimeoutStartSec = "30min";
        Environment = "HOME=/var/lib/mail-atlas-reconcile";
        StateDirectory = "mail-atlas-reconcile";
        User = "root";
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };

    systemd.timers.mail-atlas-reconcile = lib.mkIf cfg.reconcile.enable {
      description = "Reconcile the mail-atlas inbox with the real mailbox";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.reconcile.schedule;
        Persistent = true;
        RandomizedDelaySec = "2m";
      };
    };

    services.nginx.virtualHosts.mail-atlas = {
      listen = [
        {
          addr = "127.0.0.1";
          port = cfg.port;
        }
      ];
      root = site;
      locations."/" = {
        # A single page: `index.html` is what nginx already looks for, and the
        # client keeps its state in the query string rather than in a route.
        extraConfig = ''
          add_header Cache-Control "no-cache";
        '';
      };
      # A wrong content type makes `instantiateStreaming` refuse the module, and
      # the nginx mime table predates wasm in some builds — say it here.
      locations."= /particles.wasm" = {
        extraConfig = ''
          default_type application/wasm;
          add_header Cache-Control "public, max-age=300";
        '';
      };
      locations."= /han.woff" = {
        extraConfig = ''
          default_type font/woff;
          add_header Cache-Control "public, max-age=86400";
        '';
      };
      # The API publishes its contract at its own root, but the page only talks
      # to `/api/` — so the same document is reachable here under the one origin
      # the browser is allowed to use.
      locations."= /openapi.json" = {
        proxyPass = "http://127.0.0.1:${toString archive.port}/openapi.json";
      };
      # Same origin as the page: the browser needs no CORS grant, and the API
      # stays undiscoverable from outside this vhost.
      locations."/api/" = {
        proxyPass = "http://127.0.0.1:${toString archive.port}";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_read_timeout 30s;
        '';
      };
    };
  };
}
