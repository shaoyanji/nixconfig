# Sunshine GameStream/Moonlight server profile.
#
# Turns a host into a GameStream destination so Moonlight clients (laptop,
# phone, TV box, another PC) can launch and stream games from this machine
# over the LAN.
#
# - Opens Sunshine's required firewall ports (TCP 47984/47989/48010, UDP
#   47998-48010). The base-node `firewall-baseline` already restricts
#   inbound to TCP/22; Sunshine opens its own ports on top.
# - `capSysAdmin = true` grants the privilege Sunshine needs to grab the
#   KMS/DRM plane and Wayland session output for capture (required when
#   streaming gamescope-session / Steam Big Picture).
# - Adds the `sunshine` system user to `video`, `render`, and `input` so
#   it can read GPU buffers and inject gamepad/keyboard events.
#
# Designed to compose on top of base-node + steamos (which provides the
# Gamescope/Steam stack Sunshine streams). Pair with `programs.avahi`
# already present in steamos so Moonlight clients discover the host via
# mDNS.
#
# Usage:
#   imports = [ ../../modules/profiles/sunshine.nix ];
{
  config,
  lib,
  ...
}: {
  services.sunshine = {
    enable = true;
    openFirewall = true;
    capSysAdmin = true;
  };

  # Sunshine's runtime user has to read GPU buffers (capture) and inject
  # gamepad/keyboard/mouse events over the stream. nixpkgs creates the
  # user; we add the groups via extraGroups (lists union across modules).
  users.users.sunshine.extraGroups = [
    "video"
    "render"
    "input"
  ];
}
