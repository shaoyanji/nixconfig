# The email archive on delphi: NpgsqlRest on loopback, tailnet-only through the
# `tailscale serve` mount in the portal registry. docs/email-archive.md.
{...}: {
  imports = [../../modules/services/email-archive.nix];

  services.emailArchive = {
    enable = true;
    # Flipped on once the OAuth token exists — see the checklist in
    # docs/email-archive.md. A template without its sops key fails activation,
    # so the mirror stays declared-but-off until then.
    gdrive.enable = false;
  };
}
