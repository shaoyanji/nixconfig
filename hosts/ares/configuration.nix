# ares — Steam Big Picture kiosk (i5-6500 Skylake + GTX 750 Ti).
_: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia-gt-750-ti.nix
    # Impermanence root rotation + /persist/system persistence.
    ../../modules/profiles/impermanence.nix
    ../../modules/profiles/steamos.nix
    ../../modules/profiles/base-node.nix
  ];

  # X server is required so XWayland can host legacy X11-only windows
  # that Steam spawns inside gamescope's Wayland surface.  No desktop
  # environment is configured — greetd auto-logs devji into
  # gamescope-session (real gamescope + steam -gamepadui) which is the
  # entire user-facing UI.
  services.xserver.enable = true;

  # noDE kiosk — the dms/niri greeter lives in
  # modules/profiles/impermanence-greeter.nix which is intentionally NOT
  # imported here (the dms option does not exist in the containers chain
  # closure).

  system.stateVersion = "25.05";
}
