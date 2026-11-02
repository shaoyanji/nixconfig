# atuin on every host, pointed at the one server; bash, zsh and nushell get the
# Ctrl-R UI. Key: modules/sops.nix · server: modules/services/atuin-server.nix ·
# login/import: .agents/skills/atuin/SKILL.md
{lib, ...}: {
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    # Only links where programs.zsh is enabled (modules/shell/zsh.nix); the
    # silent-stub failure is docs/nix-patterns.md item 15.
    enableZshIntegration = true;

    # The tailnet address, not atuin.frieren.lan: the .lan names only resolve
    # against frieren's resolver. Plain http, because with no session file atuin
    # stays local-only and offline.
    settings = {
      auto_sync = true;
      sync_address = "http://100.97.61.65";
      sync_frequency = "5m";
      update_check = false;
      search_mode = "fuzzy";
      style = "compact";
    };
  };

  # Clear an inherited PS0, and its export attribute, before bash-preexec hooks
  # it; mkOrder 1 puts this ahead of the integrations below. Mechanism and
  # evidence: docs/nix-patterns.md item 13.
  programs.bash.initExtra = lib.mkOrder 1 ''
    export -n PS0 2>/dev/null || true
    PS0=
  '';
}
