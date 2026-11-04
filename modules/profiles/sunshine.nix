# Sunshine GameStream/Moonlight server profile.
_: {
  services.sunshine = {
    enable = true;
    openFirewall = true;
    capSysAdmin = true;
  };

  # This pin's services.sunshine declares no user or group, so the profile
  # fails two assertions without the block below. A daemon user, no fixed
  # UID/GID: a hard-coded id is what clashes across hosts.
  users.users.sunshine = {
    isSystemUser = true;
    group = "sunshine";
    extraGroups = [
      "video" # KMS/DRM plane read for capture
      "render" # GPU buffers for game stream frames
      "input" # inject gamepad/keyboard/mouse events over the stream
    ];
  };

  # Sunshines user-group counterpart. Pinned in the round-6 fix to fix
  # the deckstation per-host check failure. NixOS auto-picks a free
  # GID; we deliberately do NOT hard-code one (would clash across
  # hosts that import this profile in the same /etc/passwd context
  # during a shared Docker build, etc).
  users.groups.sunshine = {};
}
