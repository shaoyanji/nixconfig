# Needle 3 tool router: a schema-following tool caller, not a classifier — a
# label is a decision and belongs to a decision model. A CLI, not a daemon:
# `--serve` latched onto one tool after ~40 turns. docs/mail-agent.md.
{pkgs, ...}: let
  needle = import ../../modules/scripts/needle-model.nix {inherit pkgs;};
in {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "needle-route" ''
      exec ${needle.engine}/bin/needle --model ${needle.weights} --tools ${./needle-tools.json} --prompt "$*"
    '')
  ];
}
