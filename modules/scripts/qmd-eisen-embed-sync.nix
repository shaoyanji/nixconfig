# qmd-eisen-embed-sync — deterministic multi-floor QMD embedding offload client.
#
# Wakes Eisen via WoL (skipping if already online over SSH), refreshes local BM25,
# syncs index.sqlite to Eisen NVMe, runs multi-threaded embedding on Eisen's Xeon,
# pulls the vector database and model weights back, and shuts down Eisen if it was
# woken by WoL.
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "qmd-eisen-embed-sync";
  runtimeInputs = with pkgs; [
    coreutils
    findutils
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
