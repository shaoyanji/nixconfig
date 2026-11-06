{self, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./amd-rx-5700-xt.nix
    self.modules."profiles.base-node"
    self.modules."profiles.steamos"
    self.modules."profiles.sunshine"
  ];

  # X server is required by greetd so XWayland can host any legacy
  # X11-only windows that gamescope/Steam spawn. No desktop environment
  # is configured - greetd + tuigreet + gamescope-session is the entire
  # user-facing UI.
  services.xserver.enable = true;

  system.stateVersion = "25.05";
}
