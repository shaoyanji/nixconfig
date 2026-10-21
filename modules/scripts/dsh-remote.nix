# dsh-remote — open the DeepSeek Harness that runs on a remote worker.
#
# The harness is a service on the worker (`services.dshWeb`) published under a
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
