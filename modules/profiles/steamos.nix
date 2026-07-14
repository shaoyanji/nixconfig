# SteamOS-style kiosk profile for headless Steam clients.
#
# Composes:
#   - programs.steam + gamescope-session (imported from ./steam.nix)
#   - PipeWire audio (mandatory for game audio)
#   - greetd + tuigreet login that drops the user into gamescope-session
#   - Avahi / mDNS for LAN game discovery + local network transfers
#   - 32-bit graphics packages for legacy OpenGL games
#   - All Steam network services (remotePlay, dedicatedServer,
#     localNetworkGameTransfers) — full remote play + LAN posture
#
# Designed for hosts using globalModulesContainers (noDE) so no dms, niri,
# KDE, or GNOME desktop modules leak into the closure.
#
# Usage:
#   imports = [ ../../modules/profiles/steamos.nix ];
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./steam.nix
  ];

  # gamescope binary + wayland-session files.
  programs.gamescope.enable = true;

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

  # greetd + tuigreet: minimalist console-only login that drops the user
  # directly into gamescope-session (Steam Big Picture). Exiting Big
  # Picture returns the user to tuigreet.
  services.greetd = {
    enable = true;
    settings.default_session = {
      # tuigreet auto-discovers wayland-sessions; --cmd runs after login.
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd gamescope-session";
      user = "greeter";
    };
  };

  # GPU device access — gamescope, Steam, and any XWayland app needs to open
  # /dev/dri/renderD* (render group) and /dev/dri/card0 (video group).
  # base-node.nix sets wheel + networkmanager; desktop-client.nix layers docker + video.
  # Steam-only hosts don't import desktop-client, so we add these here.
  users.users.devji.extraGroups = [ "video" "render" ];

  users.users.greeter = {
    isSystemUser = true;
    group = "greeter";
    home = "/var/empty";
    description = "greetd greeter user";
  };
  users.groups.greeter = {};
}
