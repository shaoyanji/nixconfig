{pkgs, ...}: let
  xsNotifyScript = pkgs.writeShellScriptBin "xs-notify" (builtins.readFile ../../scripts/task/xs-notify.sh);
in {
  systemd.services.xs-notify = {
    description = "Monitor xs agent-turn changes and push to Telegram @Frierenixbot";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Environment = [
        "AGENT_TURNS_TOKEN_FILE=/run/secrets/agent-turns-token"
        "BOT_TOKEN_FILE=/var/lib/xs-notify/bot.token"
        "PATH=${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gawk}/bin:${pkgs.findutils}/bin:${pkgs.curl}/bin:${pkgs.jq}/bin:${pkgs.bash}/bin"
      ];
      ExecStart = "${xsNotifyScript}/bin/xs-notify";
    };
  };

  systemd.timers.xs-notify = {
    description = "Run xs-notify every minute";
    timerConfig = {
      OnCalendar = "*-*-* *:*:00";
      Persistent = true;
    };
    wantedBy = ["timers.target"];
  };
}
