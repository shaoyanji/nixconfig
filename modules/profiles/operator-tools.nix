# The CLIs the Taskfile shells out to from PATH, so `task checks:*` can run here.
# Imported by a host that runs gates but does not get the AI/dev stacks.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.profiles.operatorTools;
in {
  options.profiles.operatorTools = {
    enable = lib.mkEnableOption "the Taskfile gate toolchain (toon, python)";

    browser = lib.mkEnableOption "the headless browser `checks:kg:canvas` drives" // {default = false;};
  };

  config = lib.mkIf cfg.enable {
    # Two tools, each pinned to the gate that calls it — a gate whose tool is
    # missing reports a failure that is really an absence, which is how delphi
    # spent a session explaining itself (2026-10-22).
    environment.systemPackages =
      [
        # `checks:toon` — scripts/task/toon-check.sh: `command -v toon`.
        pkgs.llm-agents.toon
        # `ops:tailnet:policy`, `checks:kg:canvas`, `dev:site:*` — every one is
        # stdlib-only (json, re, html, tomllib, socket), so the plain package is
        # the whole requirement.
        pkgs.python3
      ]
      ++ lib.optional cfg.browser pkgs.llm-agents.agent-browser;
  };
}
