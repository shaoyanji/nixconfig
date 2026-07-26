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
{ config
, lib
, ...
}: {
  services.sunshine = {
    enable = true;
    openFirewall = true;
    capSysAdmin = true;
  };

  # Pin note (nixpkgs 6cdc7fc76e8bf7fde9fa43a849fcaaa70e230dee):
  # nixpkgs services.sunshine in this pin DOES NOT auto-declare the
  # sunshine system user or group. Without the block below, importing
  # this profile produces two failed assertions on a host:
  #   - "Exactly one of users.users.sunshine.isSystemUser and
  #      users.users.sunshine.isNormalUser must be set."
  #   - "users.users.sunshine.group is unset. This used to default to
  #      nogroup, but this is unsafe."
  # Both surface as a toplevel build error (kellerbench system rebuild
  # fails) and as host-eval-all assertion failures on multihost eval
  # (which is what deckstation hit before the defensive group add).
  #
  # We declare the user as a daemon (long-lived background service, no
  # login, no shell) which is the right shape for Sunshine. UID/GID
  # auto-assigned by NixOS at activation (no fixed numbers needed;
  # hard-coded ones would clash across hosts).
  users.users.sunshine = {
    isSystemUser = true;
    group = "sunshine";
    extraGroups = [
      "video"  # KMS/DRM plane read for capture
      "render" # GPU buffers for game stream frames
      "input"  # inject gamepad/keyboard/mouse events over the stream
    ];
  };

  # Sunshines user-group counterpart. Pinned in the round-6 fix to fix
  # the deckstation host-eval-all failure. NixOS auto-picks a free
  # GID; we deliberately do NOT hard-code one (would clash across
  # hosts that import this profile in the same /etc/passwd context
  # during a shared Docker build, etc).
  users.groups.sunshine = { };
}
