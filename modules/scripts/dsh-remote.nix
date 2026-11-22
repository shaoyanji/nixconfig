# dsh-remote — open the DeepSeek Harness that runs on a remote worker.
#
# The harness is a service on the worker (`services.dshWeb`) published on the
# tailnet by `tailscale serve` at the worker's MagicDNS name.
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "dsh-remote";
  runtimeInputs = with pkgs; [
    openssh
    coreutils
    gnugrep
    gnused
    gawk
    curl
    xdg-utils
  ];
  text = builtins.readFile ./dsh-remote.sh;
}
