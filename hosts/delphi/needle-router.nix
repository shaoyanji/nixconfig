# Needle 3 tool router: a schema-following tool caller, not a classifier — a
# label is a decision and belongs to a decision model. A CLI, not a daemon:
# `--serve` latched onto one tool after ~40 turns. docs/mail-agent.md.
{
  self,
  pkgs,
  ...
}: let
  needle = import ../../modules/scripts/needle-model.nix {inherit pkgs;};

  # vox is the same engine behind a turn: caller, lane router, chat voice. Built
  # from its own repo (flake/cli.nix pins the revision) rather than borrowed from
  # nixpkgs, and installed HERE because this is the only host whose architecture
  # the shipped engine runs on. Without it, `task vox:*` rebuilds the binary from
  # the flake on every call; with it, the task finds `vox` on PATH and the turn
  # costs one engine pass. The weights were already in this host's closure.
  vox = self.packages.${pkgs.stdenv.hostPlatform.system}.cli.ai.vox;
in {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "needle-route" ''
      exec ${needle.engine}/bin/needle --model ${needle.weights} --tools ${./needle-tools.json} --prompt "$*"
    '')
    vox
  ];
}
