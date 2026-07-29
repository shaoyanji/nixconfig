{pkgs, ...}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia-gt-750-ti.nix
    ../../modules/profiles/impermanence.nix
    ../../modules/profiles/base-desktop-environment.nix
    ../../modules/profiles/laptop.nix
    ../../modules/profiles/steam.nix
  ];

  environment.systemPackages = with pkgs; [
    # alacritty
  ];

  # X server is required so XWayland (Niri's fallback for X11-only apps)
  # and the mkForce on services.xserver.videoDrivers = [ "nvidia" ]
  # in nvidia-gt-750-ti.nix actually take effect on the desktop case.
  # Neither base-desktop-environment.nix nor laptop.nix flips this on
  # by default, so we set it host-scoped here for ares only.
  services.xserver.enable = true;

  # seatd is required so libseat (used by Niri/Smithay and any wlroots
  # compositor) has a backend to talk to.  Without this, libseat falls
  # through to systemd-logind which is not running for the user session
  # under greetd auto-login paths, producing intermittent DRM lease
  # failures (one symptom is the same black screen this rollback fixes).
  services.seatd.enable = true;

  networking.hostName = "ares";
  system.stateVersion = "25.05";
}
