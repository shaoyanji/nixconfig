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
    # The service URL and state are scraped out of the remote answer with `sed`
    # on this side of the ssh, so the wrapper has to carry it: systemd's PATH
    # has no sed and the unit would fail on its second line of work.
    gnused
    gawk
    curl
    xdg-utils
  ];
  text = builtins.readFile ./dsh-remote.sh;
}
