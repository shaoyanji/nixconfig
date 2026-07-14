{
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./amd-rx-5700-xt.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/steamos.nix
  ];

  networking.hostName = "deckstation";

  # X server is required by greetd so XWayland can host any legacy
  # X11-only windows that gamescope/Steam spawn. No desktop environment
  # is configured - greetd + tuigreet + gamescope-session is the entire
  # user-facing UI.
  services.xserver.enable = true;

  system.stateVersion = "25.05";
}
