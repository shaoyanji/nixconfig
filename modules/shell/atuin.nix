# atuin on every host, pointed at the one server. Bash and nushell both get the
# Ctrl-R UI from here, so a shell on the laptop and a shell on the NAS search
# the same history as long as the host has run `atuin login` once.
_: {
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;

    # Plain http on the LAN: the payload is shell history, the alternative is
    # certificate plumbing for a name only this network resolves. Sync is
    # opportunistic — with no session file atuin stays local-only and offline,
    # so a fresh host still opens its own history.
    settings = {
      auto_sync = true;
      sync_address = "http://atuin.frieren.lan";
      sync_frequency = "5m";
      update_check = false;
      search_mode = "fuzzy";
      style = "compact";
    };
  };
}
