# SteamOS-style kiosk profile for headless Steam clients.
{lib, ...}: {
  imports = [
    ./steam.nix
  ];

  # 32-bit graphics packages for legacy OpenGL Steam games. mkForce so
  # this wins over GPU modules (e.g. amd-rx-5700-xt sets enable32Bit=false).
  hardware.graphics.enable32Bit = lib.mkForce true;

  # Audio stack — required for game audio on a Steam-only box.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  services.pulseaudio.enable = false;

  # LAN discovery for Steam local game transfers / broadcasts.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  # seatd: libseat backend for gamescope's wlroots-based wlserver.
  # Without an enabled seatd, libseat falls through to systemd-logind
  # or builtin, which intermittently fails to acquire a seat under
  # greetd-launched Wayland sessions. The user-reported symptom is
  # `wlserver: libseat backend ...` and gamescope never comes up, so
  # the user lands back on the kernel TTY.
  services.seatd.enable = true;

  # Auto-login directly into the gamescope Steam session as devji. greetd
  # runs default_session as the target user without showing a login prompt
  # when user+command are both set, eliminating the tuigreet step
  # entirely. After the Steam Big Picture session exits, greetd
  # re-launches the same session, giving permanent auto-login behavior.
  #
  # The command is `steam-gamescope`, the wrapper `programs.steam.
  # gamescopeSession.enable` (set in ./steam.nix) puts on PATH. The older
  # upstream `gamescope-session` script no longer exists in nixpkgs, and
  # naming it here is a hard failure rather than a fallback: greetd's
  # session exits immediately, the unit burns its start limit and the kiosk
  # comes back from a reboot on a bare TTY with no Steam at all.
  services.greetd = {
    enable = true;
    settings.default_session = {
      user = "devji";
      command = "steam-gamescope";
    };
  };

  # GPU + seatd device access — gamescope, Steam, and any XWayland app needs to open
  # /dev/dri/renderD* (render group), /dev/dri/card0 (video group), /dev/input/event*
  # (input group), and the seatd socket at /run/seatd.sock (seat group).
  # base-node.nix sets wheel + networkmanager; desktop-client.nix layers docker + video.
  # Steam-only hosts don't import desktop-client, so we add these here.
  # `seat` group is required so devji can talk to libseat once greetd has
  # switched away from the `greeter` user to run gamescope-session.
  users.users.devji.extraGroups = ["video" "render" "input" "seat"];
}
