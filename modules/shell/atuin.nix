# atuin on every host, pointed at the one server. Bash and nushell both get the
# Ctrl-R UI from here, so a shell on the laptop and a shell on the NAS search
# the same history as long as the host has run `atuin login` once.
_: {
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;

    # The tailnet address, not atuin.frieren.lan: the .lan names only resolve on
    # hosts pointed at frieren's resolver, and a laptop that is off the LAN still
    # syncs fine over tailscale. Plain http because the payload is shell history
    # and the alternative is certificate plumbing for one host. Sync is
    # opportunistic — with no session file atuin stays local-only and offline, so
    # a fresh host still opens its own history.
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
