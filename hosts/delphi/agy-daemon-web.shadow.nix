# hosts/delphi/agy-daemon-web.shadow.nix — the Antigravity remote-control
# gateway, retired from hosts/delphi/configuration.nix in the deep-slash (xs
# subject nixconfig:deep-slash-dsh-agy).
#
# Two different agy lanes lived here: the headless cascade calls
# `agy -p` from agentScheduler jobs and stays, while `remote-control serve`
# is the interactive gateway that lets antigravity.google.com drive a session
# on this host. A 24/7 remote-operator door on a cloud box is the surface the
# slash exists to remove; reviving it is uncommenting the unit back into
# hosts/delphi/configuration.nix.
{...}: {
  # systemd.user.services.antigravity-cli-daemon = {
  #   description = "antigravity remote-control daemon";
  #   after = ["network.target"];
  #   unitConfig = {
  #     StartLimitIntervalSec = 0;
  #   };
  #   serviceConfig = {
  #     Type = "simple";
  #     Environment = [
  #       ''"SSH_CLIENT=127.0.0.1 1 1"''
  #       ''"SSH_CONNECTION=127.0.0.1 1 127.0.0.1 22"''
  #       "HOME=${user.home}"
  #       "USER=${user.name}"
  #       "PATH=${user.home}/.nix-profile/bin:/etc/profiles/per-user/${user.name}/bin:/run/current-system/sw/bin"
  #       "SHELL=/run/current-system/sw/bin/bash"
  #     ];
  #     ExecStart = "${pkgs.antigravity-cli}/bin/agy remote-control serve";
  #     Restart = "on-failure";
  #     RestartSec = "10s";
  #     RestartPreventExitStatus = 3;
  #     TimeoutStopSec = "30s";
  #     StandardOutput = "journal";
  #     StandardError = "journal";
  #   };
  #   wantedBy = ["default.target"];
  # };
}
