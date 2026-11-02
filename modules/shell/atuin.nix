# atuin on every host, pointed at the one server; bash, zsh and nushell all get
# the Ctrl-R UI. Key: modules/sops.nix · server:
# modules/services/atuin-server.nix · login/import procedure:
# .agents/skills/atuin/SKILL.md
#
# The zsh half only takes effect where programs.zsh is enabled
# (modules/shell/zsh.nix). A host that logs in to zsh without it keeps zsh's
# new-user stub and gets no history integration at all — measured on fern
# 2026-11-01: a 5-line ~/.zshrc, no atuin, no starship, no aliases.
{lib, ...}: {
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    enableZshIntegration = true;

    # The tailnet address, not atuin.frieren.lan: the .lan names only resolve
    # against frieren's resolver, while tailscale works off the LAN. Plain http
    # because the payload is shell history and the alternative is certificate
    # plumbing; with no session file atuin stays local-only and offline.
    settings = {
      auto_sync = true;
      sync_address = "http://100.97.61.65";
      sync_frequency = "5m";
      update_check = false;
      search_mode = "fuzzy";
      style = "compact";
    };
  };

  # bash-preexec appends its preexec hook to PS0, and bash prints any part of PS0
  # that is not the `${ …; }` form at every prompt — so a foreign PS0 inherited from
  # a parent shell prints itself in every new terminal. Clear it and its export
  # attribute before bash-preexec installs its hook; the mechanism and the evidence
  # are in docs/nix-patterns.md ("Agent failure modes", item 13).
  # mkOrder 1: this has to run before the integrations below, not after them.
  programs.bash.initExtra = lib.mkOrder 1 ''
    export -n PS0 2>/dev/null || true
    PS0=
  '';
}
