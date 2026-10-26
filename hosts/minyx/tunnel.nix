# The tunnel role: the shortcuts and long-lived forwards that make minyx usable
# as a jump host, expressed as native NixOS options so no Home Manager layer is
# needed to get them.
{
  lib,
  pkgs,
  ...
}: let
  user = import ../../modules/global/user.nix;

  # gh takes its token from a file, never from the session environment: an
  # exported GH_TOKEN is world-readable in /proc and in every child process.
  ghcs = pkgs.writeShellScriptBin "ghcs" ''
    set -eu
    if [ ! -r /run/secrets/github-token ]; then
      echo "ghcs: /run/secrets/github-token is missing — sops is not enrolled on this host yet" >&2
      exit 1
    fi
    GH_TOKEN=$(cat /run/secrets/github-token)
    export GH_TOKEN
    exec ${pkgs.gh}/bin/gh codespace ssh "$@"
  '';

  # Long-lived forwards: one systemd unit per entry, so a dropped link heals
  # itself without anyone logging in. Add an entry and rebuild.
  #
  #   immich = "-L 2283:localhost:2283 delphi";
  #
  # starts tunnel-immich.service running
  #   ssh -N -o ExitOnForwardFailure=yes … -L 2283:localhost:2283 delphi
  tunnels = {};
in {
  programs.ssh.extraConfig = ''
    # delphi — the always-on cloud outpost; address from inventory.toml.
    Host delphi
      HostName 100.123.145.53
      User ${user.name}
      ServerAliveInterval 30
      ServerAliveCountMax 3
      ExitOnForwardFailure yes
  '';

  environment.systemPackages = [ghcs];

  systemd.services =
    lib.mapAttrs' (
      name: args:
        lib.nameValuePair "tunnel-${name}" {
          description = "Persistent SSH tunnel: ${name}";
          after = ["network-online.target"];
          wants = ["network-online.target"];
          wantedBy = ["multi-user.target"];
          # Restart forever: a flaky link is the normal case for this box.
          unitConfig.StartLimitIntervalSec = 0;
          serviceConfig = {
            User = user.name;
            ExecStart = "${pkgs.openssh}/bin/ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 ${args}";
            Restart = "always";
            RestartSec = 10;
          };
        }
    )
    tunnels;
}
