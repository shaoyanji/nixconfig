# hosts/frieren/agy-daemon-web.shadow.nix — the Antigravity remote-control
# gateway, retired from hosts/frieren/infra-stack.nix in the deep-slash (xs
# subject nixconfig:deep-slash-dsh-agy). Same rationale as
# hosts/delphi/agy-daemon-web.shadow.nix: the cascade drives `agy -p`
# headless, so the interactive remote-operator lane was an idle 24/7 unit.
# Revive by uncommenting the unit back into hosts/frieren/infra-stack.nix.
_: {
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
  #       "USER=devji"
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
