# atuin on every host, pointed at the one server: bash and nushell both get the
# Ctrl-R UI, so a shell searches one history. The shared encryption key is
# `atuin.key` in modules/secrets.yaml, rendered to atuin's default path by
# modules/sops.nix; the session is per host (`atuin login`), and `atuin import`
# seeds the history that predates atuin.
_: {
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;

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
}
