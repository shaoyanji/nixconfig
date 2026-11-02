# The email archive on delphi: NpgsqlRest on loopback, tailnet-only through the
# `tailscale serve` mount in the portal registry. docs/email-archive.md.
{...}: {
  imports = [../../modules/services/email-archive.nix];

  services.emailArchive = {
    enable = true;
    # The timer runs from the first boot; the sync unit is skipped until the
    # operator writes the rclone remote (docs/email-archive.md). Same rule as the
    # calendar's token: `ConditionPathExists` on state, never a sops key.
    gdrive.enable = true;
  };
}
