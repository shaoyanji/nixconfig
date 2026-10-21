# dsh-remote — open the DeepSeek Harness that runs on a remote worker.
#
# The harness is a service on the worker (`services.dshWeb`) published under a
# path prefix by that host's TLS vhost; this is the client side: read the
# current signed-in URL from the worker's journal, prove the ingress from here,
# hand it to a browser. The script lives in `dsh-remote.sh` beside this file —
# it is the part that changes, and a Nix string would make every `$` a quoting
# exercise no linter can see.
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "dsh-remote";
  runtimeInputs = with pkgs; [
    openssh
    coreutils
    gnugrep
    gawk
    curl
    xdg-utils
  ];
  text = builtins.readFile ./dsh-remote.sh;
}
