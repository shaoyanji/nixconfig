# Sunshine GameStream/Moonlight server profile.
_: {
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
  # fails) and as per-host evaluation check failures on multihost eval
  # (hostChecks.<arch>.<host>; this is what deckstation hit before the
  # defensive group add).
  #
  # We declare the user as a daemon (long-lived background service, no
  # login, no shell) which is the right shape for Sunshine. UID/GID
  # auto-assigned by NixOS at activation (no fixed numbers needed;
  # hard-coded ones would clash across hosts).
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
