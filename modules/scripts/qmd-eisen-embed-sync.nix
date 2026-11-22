# qmd-eisen-embed-sync — deterministic multi-floor QMD embedding offload client.
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "qmd-eisen-embed-sync";
  runtimeInputs = with pkgs; [
    coreutils
    findutils
    # REPO=$(git rev-parse --show-toplevel) is the script's first real call.
    git
    openssh
    rsync
    python3
    sqlite
    nix
    gnugrep
    gnused
    gawk
  ];
  text = builtins.readFile ../../scripts/task/qmd-eisen-embed-sync.sh;
}
