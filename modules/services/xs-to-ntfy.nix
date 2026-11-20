{pkgs, ...}: let
  xsToNtfyScript = pkgs.writeShellScriptBin "xs-to-ntfy" (builtins.readFile ../../scripts/task/xs-notify.sh);
in {
  systemd.services.xs-to-ntfy = {
    description = "Monitor xs agent-turn changes and push to ntfy fleet topic";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Environment = [
        "AGENT_TURNS_TOKEN_FILE=/run/secrets/agent-turns-token"
        "NTFY_PASS_FILE=/run/secrets/ntfy/fleet-password"
        "PATH=${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gawk}/bin:${pkgs.findutils}/bin:${pkgs.curl}/bin:${pkgs.jq}/bin:${pkgs.bash}/bin"
      ];
      ExecStart = "${xsToNtfyScript}/bin/xs-to-ntfy";
    };
  };

  systemd.timers.xs-to-ntfy = {
    description = "Run xs-to-ntfy every minute";
    timerConfig = {
      OnCalendar = "*-*-* *:*:00";
      Persistent = true;
    };
    wantedBy = ["timers.target"];
  };
}
