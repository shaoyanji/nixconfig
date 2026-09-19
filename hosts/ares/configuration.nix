# ares — Steam Big Picture kiosk (i5-6500 Skylake + GTX 750 Ti).
#
# Hardware:
#   CPU:  Intel i5-6500 (Skylake, 4c/4t)
#   GPU:  NVIDIA GTX 750 Ti (Kepler sm_30, legacy_580 driver)
#   Boot: UEFI (systemd-boot) — disko btrfs layout on /dev/sda
#         (@root ephemeral, /persist + /nix subvolumes)
#
# Role:  Steam Big Picture kiosk mirroring kellerbench/deckstation.  greetd
#        auto-logs devji into gamescope-session (real gamescope + steam
#        -gamepadui) on boot — the entire user-facing UI.  Root is
#        recreated each boot (impermanence); devji home + /etc are
#        persisted to /persist.
#
# NOTE:  GTX 750 Ti is Kepler sm_30 — the same GPU as kellerbench.  The
#        old host-scoped programs.steam.gamescopeSession.enable = mkForce
#        false override (which forced a cage-based wrapper) has been
#        REMOVED: the original "Creating headless backend" crash was a
#        misdiagnosis — Steam was just downloading its ~400 MB bootstrap.
#        Real gamescope works on legacy_580 with nvidia_drm KMS enabled
#        (see ./nvidia-gt-750-ti.nix).
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

  networking.hostName = "ares";

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
