# TRANSITIONAL. Delete this file and its import once frieren is rebuilt.
#
# frieren's nginx still answers four of these ports on its own loopback, so one ssh
# connection carries them back here until `hosts/frieren/reverse-proxy.nix` names
# this host's tailnet address and that config is deployed. sshd's default
# `GatewayPorts no` binds them on frieren's loopback, which is what nginx needs.
# The move, the ladder and the switch-back: docs/service-offload.md.
{
  pkgs,
  lib,
  ...
}: let
  user = import ../../modules/global/user.nix;

  # paperless web, vaultwarden web, vaultwarden websocket, anki sync.
  ports = [
    28981
    8222
    3012
    27701
  ];
  forwards = lib.concatMapStrings (p: "-R 127.0.0.1:${toString p}:127.0.0.1:${toString p} ") ports;
in {
  systemd.services.offload-tunnel = {
    description = "Transitional reverse tunnel: frieren loopback ports to offloaded services on delphi";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target" "tailscaled.service"];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 10;
      # A port still held by frieren's own copy must fail loudly and retry, never
      # come up short of a forward and serve 502s.
      ExecStart = pkgs.writeShellScript "offload-tunnel-start" ''
        exec ${pkgs.openssh}/bin/ssh -N \
          -o BatchMode=yes \
          -o ExitOnForwardFailure=yes \
          -o ServerAliveInterval=30 \
          -o ServerAliveCountMax=3 \
          -o StrictHostKeyChecking=accept-new \
          -o UserKnownHostsFile=/var/lib/offload-bridge/known_hosts \
          -i /home/${user.name}/.ssh/id_ed25519 \
          ${forwards}${user.name}@frieren
      '';
    };
  };
}
