# Agent turns -> a Telegram alert. The xs turn log is coordination state on
# delphi; this watcher polls the shim, diffs turn outcomes, and pushes what
# changed to @Frierenixbot. It replaced the libnotify toaster the desktop
# profiles originally imported it for (ea0e6766) — hosts that still set
# `services.xsNotify.enable` for toasts were switched off when the toaster
# went, and only delphi enables this lane now.
#
# The bot token is the `hermes` sops key — env-format, so it reaches the unit
# through EnvironmentFile rather than a bare-token file — aliased under this
# service's name so a rotation in sops lands on the next switch. The script's
# bare-token file stays as the fallback for hand runs.
{
  config,
  lib,
  pkgs,
  systemdJobs,
  ...
}: let
  cfg = config.services.xsNotify;

  xsNotifyScript = pkgs.writeShellApplication {
    name = "xs-notify";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      diffutils
      gawk
      jq
      # The sha1 comparison pipes through awk, and the unit's systemd PATH has
      # coreutils, findutils, grep, sed and systemd but no awk: the wrapper has
      # to supply it or the unit dies at line 49 with status 127 (2026-11-22).
      gawk
    ];
    text = builtins.readFile ../../scripts/task/xs-notify.sh;
  };

  # Same skeleton as the rest of the fleet's timer jobs (lib/systemd-jobs.nix):
  # a Type=oneshot service under a timers.target/Persistent timer.
  job = systemdJobs.mkTimerJob {Type = "oneshot";} {
    description = "Monitor xs agent-turn changes and push to Telegram @Frierenixbot";
    timerDescription = "Run xs-notify every minute";
    onCalendar = "*-*-* *:*:00";
    after = [
      "network-online.target"
      "agent-turns-shim.service"
    ];
    wants = ["network-online.target"];
    serviceConfig = {
      User = "root";
      EnvironmentFile = [config.sops.secrets."xs-notify-telegram".path];
      Environment = [
        "XS_TURNS_URL=${cfg.url}"
        "AGENT_TURNS_TOKEN_FILE=/run/secrets/agent-turns-token"
        "TELEGRAM_CHAT_ID=${cfg.chatId}"
        "STATE_DIR=/var/lib/xs-notify"
      ];
      StateDirectory = "xs-notify";
      ExecStart = "${xsNotifyScript}/bin/xs-notify";
    };
  };
in {
  options.services.xsNotify = {
    enable = lib.mkEnableOption "the minutely watcher pushing xs turn outcome changes to Telegram";

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://delphi.cloudforest-kardashev.ts.net:8449/v1/events";
      description = ''
        The shim's events endpoint. Delphi serves the store on the tailnet
        mount; the host that runs this lane points at its loopback instead.
      '';
    };

    telegramSecret = lib.mkOption {
      type = lib.types.str;
      default = "hermes";
      description = ''
        sops key in modules/secrets.yaml whose env-format TELEGRAM_BOT_TOKEN
        the alerts are sent as (`hermes` is frieren's @Frierenixbot).
      '';
    };

    chatId = lib.mkOption {
      type = lib.types.str;
      default = "8679391100";
      description = "Telegram chat_id that receives the turn-change alerts.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."xs-notify-telegram" = {
      key = cfg.telegramSecret;
      owner = "root";
      mode = "0400";
      sopsFile = ../../modules/secrets.yaml;
    };

    systemd.services.xs-notify = job.service;
    systemd.timers.xs-notify = job.timer;
  };
}
