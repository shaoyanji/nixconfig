# Needle 3 tool router for repository and fleet questions. A CLI, not a daemon —
# `--serve` latched onto one tool after ~40 turns. Engine and weights are shared
# with the mail agent: modules/scripts/needle-model.nix.
{pkgs, ...}: let
  needle = import ../../modules/scripts/needle-model.nix {inherit pkgs;};
in {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "needle-route" ''
      exec ${needle.engine}/bin/needle --model ${needle.weights} --tools ${./needle-tools.json} --prompt "$*"
    '')
  ];
}
