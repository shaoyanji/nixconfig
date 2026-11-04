# wiki-ask — gated fan-out retrieval over the local ZIM archives. What it adds to
# `wikisearch`, and the measured comparison: `.agents/skills/wikisearch/SKILL.md`.
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "wiki-ask";
  # `toon` is deliberately absent: `--toon` resolves it from the caller's PATH
  # (it is system-wide on frieren), and the task pipes JSON through `toon -e`
  # instead, which keeps the wire format JSON
  # ([[flake/policies.nix#agent-boundary-is-toon]]).
  runtimeInputs = with pkgs; [python3 kiwix-tools coreutils];
  text = ''
    exec python3 ${./wiki-ask.py} "$@"
  '';
}
