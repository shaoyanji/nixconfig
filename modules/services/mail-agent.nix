# Mail agent: plain-English mail actions through himalaya, routed by Needle 3,
# plus a nightly sweep of bulk mail. Home-manager module because the himalaya
# config and the sops mail secret are user state. docs/mail-agent.md.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.mailAgent;
  needle = import ../scripts/needle-model.nix {inherit pkgs;};

  # One directory, so the harness finds its sibling tool schemas in the store.
  src = pkgs.runCommand "mail-agent-src" {} ''
    mkdir -p $out
    install -m 0644 ${./mail-agent.py} $out/mail-agent.py
    install -m 0644 ${./mail-agent-tools.json} $out/mail-agent-tools.json
    install -m 0644 ${./mail-agent-sort-tools.json} $out/mail-agent-sort-tools.json
  '';

  package = pkgs.writeShellApplication {
    name = "mail-agent";
    runtimeInputs = [pkgs.python3 pkgs.himalaya];
    text = ''
      export MAIL_AGENT_NEEDLE=${needle.engine}/bin/needle
      export MAIL_AGENT_WEIGHTS=${needle.weights}
      export MAIL_AGENT_INBOX=${lib.escapeShellArg cfg.inbox}
      export MAIL_AGENT_ARCHIVE=${lib.escapeShellArg cfg.archiveMailbox}
      export MAIL_AGENT_AUDIT="${cfg.auditFile}"
      ${lib.optionalString (cfg.account != "") "export MAIL_AGENT_ACCOUNT=${lib.escapeShellArg cfg.account}"}
      export MAIL_AGENT_TRUSTED=${lib.escapeShellArg (lib.concatStringsSep "," cfg.sweep.trustedSenders)}
      export MAIL_AGENT_MIN_CONF=${toString cfg.minConfidence}
      exec ${pkgs.python3}/bin/python3 ${src}/mail-agent.py "$@"
    '';
  };
in {
  options.programs.mailAgent = {
    enable = lib.mkEnableOption "the Needle 3 mail agent";

    account = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "himalaya account name; empty uses the configured default.";
    };

    inbox = lib.mkOption {
      type = lib.types.str;
      default = "inbox";
      description = "Mailbox the agent reads and removes from.";
    };

    archiveMailbox = lib.mkOption {
      type = lib.types.str;
      default = "[Gmail]/All Mail";
      description = ''
        Where archived mail goes. Gmail has no Archive folder: dropping the INBOX
        label is what archiving means, and a move to All Mail is that edit.
      '';
    };

    minConfidence = lib.mkOption {
      type = lib.types.float;
      default = 0.2;
      description = ''
        Sweep threshold on the model's confidence. Measured on Needle 3, honest
        archive calls land at 0.14–0.32, so 0.5 would never fire; `mail-agent
        --self-test` is what re-calibrates this.
      '';
    };

    limit = lib.mkOption {
      type = lib.types.ints.positive;
      default = 25;
      description = "Most recent envelopes the agent considers in one run.";
    };

    auditFile = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/state/mail-agent/audit.jsonl";
      description = "Append-only log of every applied action.";
    };

    sweep = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Nightly sweep of bulk mail.";
      };

      mode = lib.mkOption {
        type = lib.types.enum ["report" "apply"];
        default = "report";
        description = ''
          `report` lists what it would archive and changes nothing; `apply`
          archives the approved set. Only senders in
          {option}`sweep.trustedSenders` are ever approved, because on a dry run
          over the real inbox the model approved a Dropbox "new app connected"
          and a GitHub "new SSH key" (docs/mail-agent.md).
        '';
      };

      trustedSenders = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Addresses or domains the sweep may archive from. Everything else is
          held for review, so an empty list means the sweep can never act.
        '';
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "06:30";
        description = "OnCalendar time for the sweep, in HH:MM.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [package];

    systemd.user.services.mail-agent-sweep = lib.mkIf cfg.sweep.enable {
      Unit = {
        Description = "Archive bulk mail (Needle 3 gate on the deterministic bulk rule)";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart =
          "${package}/bin/mail-agent --sweep --limit ${toString cfg.limit}"
          + lib.optionalString (cfg.sweep.mode == "apply") " --apply";
        # A sweep that dies mid-run must not leave the timer disabled.
        SuccessExitStatus = [2];
      };
    };

    systemd.user.timers.mail-agent-sweep = lib.mkIf cfg.sweep.enable {
      Unit.Description = "Nightly bulk-mail sweep";
      Timer = {
        OnCalendar = "*-*-* ${cfg.sweep.schedule}:00";
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
